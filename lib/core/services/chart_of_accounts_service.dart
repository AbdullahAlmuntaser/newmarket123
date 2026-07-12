import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:supermarket/core/constants/account_codes.dart';
import 'package:supermarket/core/constants/app_enums.dart';
import 'package:supermarket/core/models/accounting/account_tree_node.dart';
import 'package:supermarket/core/services/app_config_service.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class ChartOfAccountsService {
  final AppDatabase db;
  late final AppConfigService _configService;

  ChartOfAccountsService(this.db) {
    _configService = AppConfigService(db);
  }

  Future<void> seedDefaultAccounts({String? branchId}) async {
    final dao = db.accountingDao;
    final effectiveBranchId =
        branchId ?? await _getDefaultBranchId();

    final accounts = {
      AccountCodes.cash: GLAccountsCompanion.insert(
        code: AccountCodes.cash,
        name: 'الصندوق',
        accountType: AccountType.asset,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.bank: GLAccountsCompanion.insert(
        code: AccountCodes.bank,
        name: 'البنك',
        accountType: AccountType.asset,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.accountsReceivable: GLAccountsCompanion.insert(
        code: AccountCodes.accountsReceivable,
        name: 'الذمم المدينة',
        accountType: AccountType.asset,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.inventory: GLAccountsCompanion.insert(
        code: AccountCodes.inventory,
        name: 'المخزون',
        accountType: AccountType.asset,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.inputVAT: GLAccountsCompanion.insert(
        code: AccountCodes.inputVAT,
        name: 'ضريبة المدخلات (المشتريات)',
        accountType: AccountType.asset,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.fixedAssets: GLAccountsCompanion.insert(
        code: AccountCodes.fixedAssets,
        name: 'الأصول الثابتة',
        accountType: AccountType.asset,
        isHeader: const Value(true),
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.accumulatedDepreciation: GLAccountsCompanion.insert(
        code: AccountCodes.accumulatedDepreciation,
        name: 'مجمع الإهلاك',
        accountType: AccountType.asset,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.accountsPayable: GLAccountsCompanion.insert(
        code: AccountCodes.accountsPayable,
        name: 'الذمم الدائنة',
        accountType: AccountType.liability,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.outputVAT: GLAccountsCompanion.insert(
        code: AccountCodes.outputVAT,
        name: 'ضريبة المخرجات (المبيعات)',
        accountType: AccountType.liability,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.loansPayable: GLAccountsCompanion.insert(
        code: AccountCodes.loansPayable,
        name: 'القروض',
        accountType: AccountType.liability,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.capital: GLAccountsCompanion.insert(
        code: AccountCodes.capital,
        name: 'رأس المال',
        accountType: AccountType.equity,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.retainedEarnings: GLAccountsCompanion.insert(
        code: AccountCodes.retainedEarnings,
        name: 'الأرباح المحتجزة',
        accountType: AccountType.equity,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.salesRevenue: GLAccountsCompanion.insert(
        code: AccountCodes.salesRevenue,
        name: 'إيرادات المبيعات',
        accountType: AccountType.revenue,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.salesReturns: GLAccountsCompanion.insert(
        code: AccountCodes.salesReturns,
        name: 'مردودات المبيعات',
        accountType: AccountType.revenue,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.cogs: GLAccountsCompanion.insert(
        code: AccountCodes.cogs,
        name: 'تكلفة البضاعة المباعة',
        accountType: AccountType.expense,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.purchaseReturns: GLAccountsCompanion.insert(
        code: AccountCodes.purchaseReturns,
        name: 'مردودات المشتريات',
        accountType: AccountType.expense,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.cashOverShort: GLAccountsCompanion.insert(
        code: AccountCodes.cashOverShort,
        name: 'العجز والزيادة في الصندوق',
        accountType: AccountType.expense,
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.operatingExpenses: GLAccountsCompanion.insert(
        code: AccountCodes.operatingExpenses,
        name: 'المصروفات التشغيلية',
        accountType: AccountType.expense,
        isHeader: const Value(true),
        branchId: Value(effectiveBranchId),
      ),
      AccountCodes.depreciationExpense: GLAccountsCompanion.insert(
        code: AccountCodes.depreciationExpense,
        name: 'مصروف الإهلاك',
        accountType: AccountType.expense,
        branchId: Value(effectiveBranchId),
      ),
    };

    for (var acc in accounts.values) {
      final existing = await dao.getAccountByCode(acc.code.value);
      if (existing == null) {
        await dao.createAccount(acc);
      } else if (existing.branchId == null && branchId != null) {
        await dao.updateAccount(existing.copyWith(branchId: Value(branchId)));
      }
    }
  }

  Future<String> createCustomerAccount(String customerName) async {
    final dao = db.accountingDao;
    await db.ensureCoreReferenceData();
    final parent = await dao.getAccountByCode(AccountCodes.accountsReceivable);
    if (parent == null) {
      throw Exception(
        'حساب الذمم المدينة الرئيسي (${AccountCodes.accountsReceivable}) غير موجود. يجب إنشاءه أولاً من شجرة الحسابات.',
      );
    }

    final existingSubAccounts = await (db.select(db.gLAccounts)
      ..where((a) => a.parentId.equals(parent.id)))
        .get();
    final nextNumber = (existingSubAccounts.length + 1)
        .toString()
        .padLeft(4, '0');
    final newCode = '${parent.code}.$nextNumber';

    final id = const Uuid().v4();
    final defaultBranchId = await _getDefaultBranchId();
    final branch = await (db.select(db.branches)
      ..where((b) => b.id.equals(defaultBranchId)))
        .getSingleOrNull();
    if (branch == null) {
      throw Exception('الفرع الافتراضي غير موجود. تعذر إنشاء حساب العميل.');
    }
    await dao.createAccount(
      GLAccountsCompanion.insert(
        id: Value(id),
        code: newCode,
        name: 'حساب عميل: $customerName',
        accountType: AccountType.asset,
        parentId: Value(parent.id),
        branchId: Value(defaultBranchId),
      ),
    );
    return id;
  }

  Future<String> createSupplierAccount(String supplierName) async {
    final dao = db.accountingDao;
    await db.ensureCoreReferenceData();
    final parent = await dao.getAccountByCode(AccountCodes.accountsPayable);
    if (parent == null) {
      throw Exception(
        'حساب الذمم الدائنة الرئيسي غير موجود. تعذر إنشاء حساب المورد.',
      );
    }

    final existingSubAccounts = await (db.select(db.gLAccounts)
      ..where((a) => a.parentId.equals(parent.id)))
        .get();
    final nextNumber = (existingSubAccounts.length + 1)
        .toString()
        .padLeft(4, '0');
    final newCode = '${parent.code}.$nextNumber';

    final id = const Uuid().v4();
    final defaultBranchId = await _getDefaultBranchId();
    final branch = await (db.select(db.branches)
      ..where((b) => b.id.equals(defaultBranchId)))
        .getSingleOrNull();
    if (branch == null) {
      throw Exception('الفرع الافتراضي غير موجود. تعذر إنشاء حساب المورد.');
    }
    await dao.createAccount(
      GLAccountsCompanion.insert(
        id: Value(id),
        code: newCode,
        name: 'حساب مورد: $supplierName',
        accountType: AccountType.liability,
        parentId: Value(parent.id),
        branchId: Value(defaultBranchId),
      ),
    );
    return id;
  }

  Future<List<AccountTreeNode>> getAccountTree({
    DateTime? asOfDate,
    String? branchId,
  }) async {
    return db.accountingDao.getAccountTree(
      asOfDate: asOfDate,
      branchId: branchId,
    );
  }

  Future<Decimal> getAccountTreeBalance(
    String accountId, {
    DateTime? asOfDate,
    String? branchId,
  }) async {
    return db.accountingDao.getAccountTreeBalance(
      accountId,
      asOfDate: asOfDate,
      branchId: branchId,
    );
  }

  Future<String> _getDefaultBranchId() async {
    return await _configService.getDefaultBranchId();
  }
}
