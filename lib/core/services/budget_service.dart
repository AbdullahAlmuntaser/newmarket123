import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/utils/notification_service.dart';

class BudgetService {
  final AppDatabase db;
  final NotificationService notificationService;

  BudgetService(this.db, this.notificationService);

  /// التحقق من توافر الميزانية قبل تسجيل المصروف
  Future<void> validateExpenseAgainstBudget({
    required int costCenterId,
    required double expenseAmount,
    required String period,
  }) async {
    final budgets = await (db.select(db.accBudgets)
          ..where((b) => b.costCenterId.equals(costCenterId))
          ..where((b) => b.period.equals(period)))
        .get();

    for (var budget in budgets) {
      final remaining = budget.budgetedAmount - budget.actualAmount;
      
      // 1. منع التجاوز
      if (expenseAmount > remaining) {
        throw Exception(
          'تنبيه: المبلغ المطلوب يتجاوز الميزانية المتبقية لمركز التكلفة ${budget.name}. المتبقي: ${remaining.toStringAsFixed(2)}',
        );
      }

      // 2. إرسال تنبيه إذا تجاوز الاستهلاك 90%
      final consumption = (budget.actualAmount + expenseAmount) / budget.budgetedAmount;
      if (consumption >= 0.9) {
        await notificationService.showNotification(
          costCenterId,
          'تنبيه ميزانية',
          'مركز التكلفة ${budget.name} استهلك ${ (consumption * 100).toStringAsFixed(0) }% من الميزانية المخصصة.',
        );
      }
    }
  }

  /// تحديث الميزانية عند تسجيل مصروف فعلي
  Future<void> updateActualBudget({
    required int costCenterId,
    required double expenseAmount,
    required String period,
  }) async {
    final budgets = await (db.select(db.accBudgets)
          ..where((b) => b.costCenterId.equals(costCenterId))
          ..where((b) => b.period.equals(period)))
        .get();

    for (var budget in budgets) {
      await (db.update(db.accBudgets)..where((b) => b.id.equals(budget.id)))
          .write(AccBudgetsCompanion(
        actualAmount: Value(budget.actualAmount + expenseAmount),
        variance: Value(budget.budgetedAmount - (budget.actualAmount + expenseAmount)),
      ));
    }
  }
}
