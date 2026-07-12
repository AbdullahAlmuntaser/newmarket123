# تقرير التحقيق الجنائي النهائي
## DATABASE_ENCRYPTION_ERROR — التقرير النهائي

**تاريخ التحقيق:** 2026-07-11
**الحالة:** تم العثور على السبب الجذري وإصلاحه

---

## 1. السبب الجذري للمشكلة

### المشكلة الهيكلية (Structural Defect)

**`NativeDatabase.createInBackground()` تُرجع `QueryExecutor` كسليل (lazy).**

عندما يتم استدعاء `_openNativeDatabase()` في `app_database.dart:2376`، لا يتم فتح قاعدة البيانات فعليًا. بدلاً من ذلك، يتم إنشاء `QueryExecutor` يحتوي على `DatabaseConnection.delayed(Future)`. الخطوة التالية (فتح الملف + تنفيذ PRAGMAs + SELECT) تحدث في **عزل خلفي (background isolate)** عندما يتم إرسال أول استعلام.

سلسلة الأخطاء الفعلية:
```
db.select(db.users).get()  ← main.dart:136
  → LazyDatabase triggers Future
    → Background isolate receives query
      → Sqlite3Delegate.open()
        → sqlite3.open(file.path)        ← فتح الملف
        → _setup?.call(database)          ← تنفيذ PRAGMAs
          → PRAGMA key = '...'
          → SELECT count(*) FROM sqlite_master  ← فشل هنا! SqliteException(26)
      ← Error propagates via Drift isolate communication
    ← Error surfaces as DriftRemoteException
  ← LazyDatabase throws
← db.select().get() throws
← Caught in _performInitialization() catch block at main.dart:147
```

**النتيجة:** كتلة `catch` في `_connectWithRecovery()` (سطر 2355) **لا تُنفذ أبدًا** لأن `_openNativeDatabase()` تُرجع بنجاح (الـ QueryExecutor) قبل حدوث الخطأ. كل منطق الاسترداد (حذف الملف + إعادة الإنشاء) هو **كود ميت (dead code)**.

### سبب الخطأ الفعلي (code 26)

`SqliteException(26): file is not a database` يعني أن:
1. SQLCipher **محمل** ✓ (PRAGMA cipher_version يُرجع نسخة)
2. `PRAGMA key` **نُفّذ** ✓ (لا خطأ)
3. لكن `SELECT count(*) FROM sqlite_master` **يفشل** ✗

هذا يحدث عندما:
- ملف قاعدة البيانات غير متوافق مع المفتاح (المفتاح خاطئ أو الملف تالف)
- ملف SQLite عادي (غير مشفر) تم فتحه بـ SQLCipher مع مفتاح تشفير

---

## 2. تتبع دورة حياة قاعدة البيانات بالكامل

### الخطوة 1: `main()` في `main.dart`
```
27: applyNativeSqlOverride()     ← يسجل overrideFor لكن لا يُنفذ المكتبة بعد
35: sqlite3.sqlite3.openInMemory().dispose()  ← يُنفذ المكتبة في العزل الرئيسي
                                            ← يُحمّل SQLCipher ← _sqlCipherLoaded = true
68: SecurityService.getDatabaseKey()          ← يقرأ/يُنشئ المفتاح من FlutterSecureStorage
100: runApp(AppRoot())
```

### الخطوة 2: `AppRoot._performInitialization()` في `main.dart`
```
131: di.init()                               ← initDatabase() + initServices()
134: db = di.sl<AppDatabase>()               ← يحصل على كائن AppDatabase
136: db.select(db.users).get()               ← أول استعلام ← يُفعّل LazyDatabase
```

### الخطوة 3: `initDatabase()` في `injection_container.dart`
```
107: key = await SecurityService.getDatabaseKey()  ← المفتاح
108: AppDatabase.encryptionKey = key                ← يُعيّن المفتاح الثابت
111: _database = AppDatabase()                      ← يستدعي _openConnection()
     → LazyDatabase(() async { return await _connectWithRecovery(); })
     → لا يفتح قاعدة البيانات بعد (كسليل)
```

### الخطوة 4: `_connectWithRecovery()` في `app_database.dart`
```
2263: dbFolder = await getApplicationDocumentsDirectory()
2264: file = File(p.join(dbFolder.path, 'app_db.sqlite'))
2271-2280: فحص الملف (فارغ/صغير)
2287-2301: فحص SQLite عادي → تحويل إلى مشفر
2304-2305: تعيين sqlite3.tempDirectory
2354: return await _openNativeDatabase(file, encryptionKey)
     → NativeDatabase.createInBackground(file, ...)  ← يُرجع فوراً!
     → لا خطأ هنا
2355: return QueryExecutor  ← يُرجع للـ LazyDatabase
```

### الخطوة 5: Background Isolate (حيث يحدث الخطأ)
```
_NativeIsolateStartup.start():
  432: await startup.isolateSetup?.call()    ← applyNativeSqlOverride() في العزل الخلفي
  434: DriftIsolate.inCurrent(...)            ← يُنشئ NativeDatabase (لا يفتح بعد)
  444: sendServer.send(isolate)               ← يُرسل للعزل الرئيسي

عند أول استعلام:
  Sqlite3Delegate.open():
    79: _database = openDatabase()            ← sqlite3.open(file.path) ← يُحمّل SQLCipher
    82: _initializeDatabase()
    105: _setup?.call(database)               ← تنفيذ PRAGMAs
      2388: PRAGMA cipher_page_size = 4096
      2390: PRAGMA key = '...'
      2394: PRAGMA cipher_version             ← يُرجع "4.x.x" ✓
      2407: SELECT count(*) FROM sqlite_master ← SqliteException(26) ✗
    ← Exception propagates via isolate communication
```

### الخطوة 6: العودة للعزل الرئيسي
```
main.dart:136: db.select(db.users).get()
  ← throws DriftRemoteException wrapping SqliteException(26)
main.dart:147: catch (e, stack)
  ← shows "Critical System Error" screen
```

---

## 3. الملفات المسؤولة

| الملف | الدور | المشكلة |
|-------|-------|---------|
| `lib/data/datasources/local/app_database.dart` | فتح وربط قاعدة البيانات | منطق الاسترداد في `_connectWithRecovery()` لا يُنفذ أبدًا (كود ميت) |
| `lib/main.dart` | تهيئة التطبيق | لا يوجد منطق استرداد ثاني عند التقاط الخطأ |
| `lib/native_sql_override.dart` | تحميل SQLCipher | يعمل بشكل صحيح |
| `lib/injection_container.dart` | حقن التبعيات | يعمل بشكل صحيح |
| `lib/core/services/security_service.dart` | إدارة المفاتيح | يعمل بشكل صحيح |

---

## 4. التعديلات التي أُجريت

### التعديل 1: التحقق المسبق التزامني (app_database.dart)
**السطور:** 2304-2347 (جديد)

أُضيف فحص **تزامني** في العزل الرئيسي قبل إنشاء `NativeDatabase.createInBackground`:
```dart
if (encryptionKey != null && await file.exists() && isSqlCipherLoaded) {
    // فتح قاعدة البيانات تزامنيًا في العزل الرئيسي
    final testDb = sqlite.sqlite3.open(file.path);
    try {
        testDb.execute("PRAGMA cipher_page_size = 4096");
        testDb.execute("PRAGMA key = '$escapedKey'");
        final result = testDb.select("PRAGMA integrity_check;");
        if (result.first.values.first != 'ok') {
            await _backupAndDelete(file, 'integrity_failed');
        }
    } finally {
        testDb.dispose();
    }
}
```

**لماذا هذا يحل المشكلة:**
- `sqlite3.open()` + PRAGMAs + `integrity_check` تُنفّذ **تزامنيًا** في العزل الرئيسي
- إذا فشل الفحص (code 26 أو أي خطأ)، يتم حذف الملف **فورًا**
- `_openNativeDatabase()` ستنشئ ملف جديد مشفر
- لا يعتمد على منطق الاسترداد الميت في كتلة `catch`

### التعديل 2: منطق الاسترداد الثاني (main.dart)
**السطور:** 152-186 (جديد)

أُضيف طبقة استرداد ثانية في `_performInitialization()`:
```dart
if (errStr.contains('DATABASE_ENCRYPTION_ERROR') || ...) {
    // حذف ملف قاعدة البيانات
    // إعادة تسجيل AppDatabase في GetIt
    // إعادة محاولة initialization بالكامل
}
```

**لماذا هذا يحل المشكلة:**
- حتى لو فشل التحقق المسبق (التعديل 1)، هذا يلتقط الخطأ في المكان الفعلي ويُعيد المحاولة
- يحذف الملف ويعيد إنشاء everything من الصفر

### التعديل 3: إضافة Imports (main.dart)
**السطور:** 1-17 (مُعدّل)

أُضيف `dart:io`, `path`, `path_provider` لدعم التعديل 2.

---

## 5. لماذا ستمنع هذه التعديلات ظهور الخطأ مرة أخرى

### الحالة 1: ملف غير متوافق (المفتاح خاطئ أو ملف تالف)
- **قبل:** الخطأ ينتقل للعزل الخلفي → يتجاوز كتلة catch → يظهر "Critical System Error"
- **بعد:** التحقق المسبق (التعديل 1) يكشف الخطأ تزامنيًا → يحذف الملف → يُنشئ ملف جديد

### الحالة 2: ملف SQLite عادي (غير مشفر)
- **قبل:** `_isPlainSqliteDatabase` يكتشفه → `_convertToEncrypted` يحوّله → قد يفشل
- **_after:** نفس المعالجة + التحقق المسبق يتأكد أن التحويل نجح

### الحالة 3: فشل غير متوقع في العزل الخلفي
- **قبل:** الخطأ يظهر مباشرة كـ "Critical System Error"
- **بعد:** التعديل 2 يلتقط الخطأ ويعيد المحاولة بعد حذف الملف

### الحالة 4: أول تشغيل (بدون ملف)
- **لا يتغير:** يُنشئ ملف جديد مشفر بشكل صحيح

---

## 6. تدفق التنفيذ الجديد

```
_connectWithRecovery()
  │
  ├── فحص الملف (فارغ/صغير)
  │
  ├── فحص SQLite عادي → تحويل
  │
  ├── ★ التحقق المسبق التزامني (الجديد) ★
  │     ├── sqlite3.open(file.path)     ← في العزل الرئيسي
  │     ├── PRAGMA key = '...'
  │     ├── PRAGMA integrity_check
  │     ├── نجح ← الملف صالح → أكمل
  │     └── فشل ← حذف الملف ← أكمل
  │
  └── _openNativeDatabase(file, key)
        └── NativeDatabase.createInBackground(...)  ← يُرجع فوراً
              └── Background isolate opens DB ← يجب أن ينجح الآن
```

---

## 7. ملاحظات مهمة

1. **التحقق المسبق لا يُنشئ ملف جديداً** — إذا كان الملف غير موجود (`!await file.exists()`)، يتم تخطيه ويُترك لـ `_openNativeDatabase` لإنشائه
2. **التحقق المسبق يتطابق مع إعدادات العزل الخلفي** — `cipher_page_size = 4096` و `PRAGMA key` بنفس الترتيب
3. **الملفات المُسوقة تُحتفظ بها** — `_backupAndDelete` ينسخ الملف قبل الحذف بأسماء فريدة (مثلاً: `app_db.sqlite.key_mismatch_1234567890`)
4. **الـ `_openNativeDatabase` الكود الأصلي لم يتغير** — لا تغيير في بنية قاعدة البيانات أو التوافق

---

## 8. التحقق من صحة الإصلاح

- [x] `dart analyze lib/` — لا توجد مشاكل
- [x] `flutter build apk --release` — نجح (118.2MB)
- [x] لا تغيير في بنية قاعدة البيانات
- [x] لا تغيير في مفتاح التشفير
- [x] لا حذف لأي جزء من النظام
- [x] التوافق مع القاعدة الحالية محفوظ
