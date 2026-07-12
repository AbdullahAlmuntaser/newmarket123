import 'package:drift/drift.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';
import 'package:supermarket/core/services/notification_service.dart';

class BudgetService {
  final AppDatabase db;
  final NotificationService notificationService;

  BudgetService(this.db, this.notificationService);

  /// التحقق من توافر الميزانية قبل تسجيل المصروف
  Future<void> validateExpenseAgainstBudget({
    required String costCenterId,
    required Decimal expenseAmount,
    required String period,
  }) async {
    final budgets = await (db.select(db.accBudgets)
          ..where((b) => b.costCenterId.equals(costCenterId))
          ..where((b) => b.period.equals(period)))
        .get();

    for (var budget in budgets) {
      final budgetedDecimal = Decimal.parse(budget.budgetedAmount.toString());
      final actualDecimal = Decimal.parse(budget.actualAmount.toString());
      final remaining = budgetedDecimal - actualDecimal;

      if (expenseAmount > remaining) {
        throw Exception(
          'تنبيه: المبلغ المطلوب يتجاوز الميزانية المتبقية لمركز التكلفة ${budget.name}. المتبقي: ${remaining.toStringAsFixed(2)}',
        );
      }

      final consumption = (actualDecimal + expenseAmount) / budgetedDecimal;
      if (consumption >= Decimal.fromInt(9) / Decimal.fromInt(10)) {
        await notificationService.showNotification(
          costCenterId.hashCode,
          'تنبيه ميزانية',
          'مركز التكلفة ${budget.name} استهلك ${(consumption.toDouble() * 100).toStringAsFixed(0)}% من الميزانية المخصصة.',
        );
      }
    }
  }

  /// تحديث الميزانية عند تسجيل مصروف فعلي
  Future<void> updateActualBudget({
    required String costCenterId,
    required Decimal expenseAmount,
    required String period,
  }) async {
    final budgets = await (db.select(db.accBudgets)
          ..where((b) => b.costCenterId.equals(costCenterId))
          ..where((b) => b.period.equals(period)))
        .get();

    for (var budget in budgets) {
      final newActual =
          Decimal.parse(budget.actualAmount.toString()) + expenseAmount;
      await (db.update(db.accBudgets)..where((b) => b.id.equals(budget.id)))
          .write(AccBudgetsCompanion(
        actualAmount: Value(newActual),
        variance:
            Value(Decimal.parse(budget.budgetedAmount.toString()) - newActual),
      ));
    }
  }
}
