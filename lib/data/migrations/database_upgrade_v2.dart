import 'package:flutter/foundation.dart';
import 'package:supermarket/data/datasources/local/app_database.dart';

class DatabaseMigration {
  static Future<void> upgradeDatabase(AppDatabase db, int oldVersion, int newVersion) async {
    await db.customStatement('PRAGMA foreign_keys = ON');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS quotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quotation_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER NOT NULL,
        branch_id INTEGER,
        warehouse_id INTEGER,
        date TEXT NOT NULL,
        expiry_date TEXT,
        status TEXT DEFAULT 'draft',
        subtotal REAL DEFAULT 0,
        discount_total REAL DEFAULT 0,
        tax_total REAL DEFAULT 0,
        total_amount REAL DEFAULT 0,
        notes TEXT,
        created_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
        FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE SET NULL,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE SET NULL,
        FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS quotation_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quotation_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        discount_percent REAL DEFAULT 0,
        discount_amount REAL DEFAULT 0,
        tax_percent REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        total_amount REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (quotation_id) REFERENCES quotations(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS bin_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        warehouse_id INTEGER NOT NULL,
        zone_code TEXT,
        aisle_code TEXT,
        rack_code TEXT,
        shelf_code TEXT,
        bin_code TEXT NOT NULL,
        capacity REAL,
        current_quantity REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE CASCADE,
        UNIQUE(warehouse_id, bin_code)
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS stock_reservations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference_type TEXT NOT NULL,
        reference_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        bin_location_id INTEGER,
        quantity REAL NOT NULL,
        reserved_quantity REAL NOT NULL,
        picked_quantity REAL DEFAULT 0,
        status TEXT DEFAULT 'pending',
        expiry_date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE CASCADE,
        FOREIGN KEY (bin_location_id) REFERENCES bin_locations(id) ON DELETE SET NULL
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS approval_workflows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        document_type TEXT NOT NULL,
        condition_type TEXT,
        condition_value REAL,
        operator TEXT,
        level_order INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS approval_levels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workflow_id INTEGER NOT NULL,
        level_order INTEGER NOT NULL,
        role TEXT,
        user_id INTEGER,
        min_amount REAL,
        max_amount REAL,
        requires_signature INTEGER DEFAULT 0,
        FOREIGN KEY (workflow_id) REFERENCES approval_workflows(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS approval_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_type TEXT NOT NULL,
        document_id INTEGER NOT NULL,
        workflow_id INTEGER NOT NULL,
        current_level INTEGER DEFAULT 1,
        status TEXT DEFAULT 'pending',
        requested_by INTEGER,
        requested_at TEXT DEFAULT CURRENT_TIMESTAMP,
        completed_at TEXT,
        FOREIGN KEY (workflow_id) REFERENCES approval_workflows(id) ON DELETE CASCADE,
        FOREIGN KEY (requested_by) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS approval_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id INTEGER NOT NULL,
        level_order INTEGER NOT NULL,
        approver_id INTEGER,
        approver_role TEXT,
        action TEXT NOT NULL,
        comments TEXT,
        action_date TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (request_id) REFERENCES approval_requests(id) ON DELETE CASCADE,
        FOREIGN KEY (approver_id) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS closing_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        closing_date TEXT NOT NULL,
        status TEXT DEFAULT 'draft',
        total_revenue REAL DEFAULT 0,
        total_expenses REAL DEFAULT 0,
        net_profit REAL DEFAULT 0,
        retained_earnings_account_id INTEGER,
        created_by INTEGER,
        posted_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        posted_at TEXT,
        FOREIGN KEY (retained_earnings_account_id) REFERENCES gl_accounts(id) ON DELETE SET NULL,
        FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
        FOREIGN KEY (posted_by) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS cash_flow_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_date TEXT NOT NULL,
        transaction_type TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        account_id INTEGER NOT NULL,
        reference_type TEXT,
        reference_id INTEGER,
        amount REAL NOT NULL,
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (account_id) REFERENCES gl_accounts(id) ON DELETE CASCADE
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS discount_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rule_type TEXT NOT NULL,
        priority INTEGER DEFAULT 1,
        start_date TEXT,
        end_date TEXT,
        is_active INTEGER DEFAULT 1,
        applies_to TEXT,
        min_quantity REAL,
        min_amount REAL,
        discount_value REAL,
        max_discount_amount REAL,
        stackable INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS discount_rule_conditions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rule_id INTEGER NOT NULL,
        condition_type TEXT NOT NULL,
        condition_value TEXT NOT NULL,
        FOREIGN KEY (rule_id) REFERENCES discount_rules(id) ON DELETE CASCADE
      )
    ''');

    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS row_level_permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        table_name TEXT NOT NULL,
        permission_type TEXT NOT NULL,
        condition_sql TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_quotations_customer ON quotations(customer_id)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_quotations_status ON quotations(status)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_quotation_items_quotation ON quotation_items(quotation_id)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_bin_locations_warehouse ON bin_locations(warehouse_id)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_stock_reservations_product ON stock_reservations(product_id)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_stock_reservations_status ON stock_reservations(status)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_approval_requests_status ON approval_requests(status)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_cash_flow_entries_date ON cash_flow_entries(entry_date)');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_discount_rules_active ON discount_rules(is_active)');

    debugPrint('تم تنفيذ جميع عمليات الترقية بنجاح');
  }
}
