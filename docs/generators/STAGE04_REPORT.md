# تقرير Stage04 — Meter Reading Offline Contract

## النسخة الأساسية

- Branch base: `agent/generators-mobile-stage03-domain-contracts`
- Stage03 commit: `712783e3a3f0e0b2f6cea36303d003240b316f26`
- لا تغيير للمستودع أو Render Service أو Base URL.

## ما تم تنفيذه في السيرفر

- مخطط إضافي مستقل لدورات وقراءات العدادات.
- دورة واحدة مفتوحة لكل مؤسسة.
- فتح وقفل الدورة بواسطة صاحب المولدة.
- سياق قراءة للجابي يعتمد على تكليفاته الحقيقية.
- القراءة السابقة محسوبة من آخر قراءة مؤكدة على السيرفر.
- استقبال `reading.create` عبر نظام المزامنة الحالي.
- Idempotency كاملة حسب Tenant وUUID وHash المحتوى.
- حفظ نتائج `applied / conflict / rejected` وإعادتها عند تكرار الإرسال.
- تعارض عند تغيّر القراءة السابقة أو وجود قراءة لنفس المشترك والدورة.
- رفض القراءة بعد قفل الدورة أو لمشترك غير مكلف.
- Audit Log لفتح الدورة وقفلها وتثبيت القراءة ونتيجة المزامنة.
- بقاء الفواتير والتحصيل والديون والمصاريف والأرباح مقفلة.

## ملفات السيرفر الجديدة

- `src/modules/generators/generators.readings.schema.sql`
- `src/modules/generators/generators.readings.service.js`
- `tests/generators_stage04.test.js`
- `tests/generators_stage04_contract.test.js`
- `docs/generators/STAGE04_ARCHITECTURE.md`
- `docs/generators/STAGE04_API.md`
- `docs/generators/STAGE04_REPORT.md`

## ملفات السيرفر المعدلة

- `src/modules/generators/generators.db.js`
- `src/modules/generators/generators.routes.js`
- `src/modules/generators/generators.sync.service.js`
- `tests/generators_stage01.test.js`
- `tests/generators_stage02_contract.test.js`
- `tests/generators_stage03.test.js`
- `tests/generators_stage03_contract.test.js`
- `package.json`

## ما تم تنفيذه في Flutter

- ترقية SQLite المحلية إلى Version 2.
- جدول `local_meter_readings` مع UUID وحالات المزامنة والأخطاء.
- Reading Repository يحفظ القراءة والحركة في Transaction واحدة.
- Sync Engine يربط `pending / sending / synced / failed / conflict` بالسجل المحلي، ويعيد محاولة حركة `sending` بعد إعادة تشغيل التطبيق بأمان.
- شاشة جابي لتسجيل القراءة بدون إنترنت وعرض السابقة والحالية والحالة.
- شاشة صاحب المولدة لفتح الدورات وقفلها ومراجعة القراءات والملخص.
- Cache لسياق الدورة والمشتركين ودورات صاحب المولدة.
- عرض آخر البيانات المؤكدة عند تعذر الاتصال.
- بقاء Base URL وSecure Storage وبنية التطبيق الواحد كما هي.

## اختبارات منفذة

تم تشغيل فحوص Syntax لملفات Node الجديدة والمعدلة، وتشغيل Harness معزول يستخدم `node:sqlite` لنفس خدمات Stage04.

النتيجة الفعلية للـHarness:

```text
2 tests passed
0 failed
```

الحالات التي اختبرها:

- فتح دورة واحدة فقط.
- قبول قراءة صحيحة.
- إعادة نفس UUID بدون تكرار.
- تعارض القراءة الثانية لنفس المشترك.
- رفض القراءة بعد قفل الدورة.
- اعتماد قراءة الدورة التالية كقراءة سابقة.
- اكتشاف القراءة السابقة القديمة من جهاز Offline.
- بقاء `collection.create` مقفلة.

تمت إضافة اختبارات Repository كاملة لـStage04 وعقود Source، لكن لم يمكن تشغيل Suite المستودع الكامل داخل بيئة التنفيذ لأن نسخ GitHub من الحاوية محجوب. يجب تشغيل:

```text
npm run test:generators
```

بعد سحب الفرع على جهاز التطوير أو عبر CI.

## فحوص Flutter

أضيف اختبار Models، وتمت مراجعة توازن ملفات Dart والاستيرادات الأساسية نصيًا. بيئة التنفيذ لا تحتوي Flutter/Dart، لذلك لم يتم الادعاء بتشغيل:

```text
flutter analyze
flutter test
flutter build apk
flutter build appbundle
```

يجب تشغيل `bootstrap_flutter.cmd` على Windows يحتوي Flutter. بناء iPhone الفعلي يبقى لاحقًا على Mac وXcode.

## ما لم ينفذ عمدًا

- لا تسعير أمبير.
- لا فواتير أو ديون.
- لا جباية كاملة أو جزئية.
- لا تعديل أو حذف قراءة مؤكدة.
- لا مصاريف أو وقود أو أرباح.
- لا GPS أو إشعارات أو طباعة أو واتساب.
- لا ربط برنامج الحاسبة.
- لا بناء iPhone على Windows.

## المرحلة التالية المقترحة

`Stage05 — Monthly Billing Calculation Contract`

تثبيت قواعد تسعير الأمبير وتحويل القراءة المؤكدة إلى مسودة فاتورة شهرية قابلة للمراجعة، مع إبقاء التحصيل والديون غير مفعلة حتى اعتماد عقد الفاتورة.
