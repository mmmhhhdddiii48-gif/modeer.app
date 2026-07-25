# تقرير Stage02 — Owner Collector Provisioning & Assignment Foundation

## النسخة الأساسية

- Branch base: `agent/generators-mobile-stage01`
- Stage01 commit: `2f9568158503f430c6db71a5dc2d4d5d2fa05618`
- لا تغيير لرابط السيرفر أو Render Service أو المستودع.

## ما تم تنفيذه في السيرفر

- إنشاء الجباة بواسطة صاحب المولدة فقط.
- فرض `collector_limit` من قاعدة البيانات.
- حالات `active / suspended / disabled` مع قواعد آمنة لإعادة التفعيل.
- تعديل ملف الجابي.
- صلاحيات Collector من Allowlist فقط.
- تغيير كلمة المرور مع Scrypt وإلغاء Refresh Tokens.
- إبطال الجلسات عند الإيقاف أو تغيير الصلاحيات.
- Tenant Isolation في كل استعلام.
- قائمة آخر وقت استلام عملية من السيرفر لكل جابٍ.
- أساس تخصيصات `generator / subscriber / route`.
- عرض تخصيصات الحساب الحالي للجابي فقط.
- Audit Log لجميع عمليات الإدارة.
- إبقاء القراءات والجبايات والفواتير والديون مقفلة.

## ملفات السيرفر الجديدة

- `src/modules/generators/generators.collectors.service.js`
- `tests/generators_stage02.test.js`
- `tests/generators_stage02_contract.test.js`
- `docs/generators/STAGE02_OWNER_COLLECTORS_ARCHITECTURE.md`
- `docs/generators/STAGE02_API.md`
- `docs/generators/STAGE02_REPORT.md`

## ملفات السيرفر المعدلة

- `src/modules/generators/generators.schema.sql`
- `src/modules/generators/generators.db.js`
- `src/modules/generators/generators.auth.service.js`
- `src/modules/generators/generators.auth.middleware.js`
- `src/modules/generators/generators.routes.js`
- `src/modules/generators/generators.sync.service.js`
- `tests/generators_stage01.test.js`
- `package.json`

## ما تم تنفيذه في Flutter

- شاشة Owner حقيقية لإدارة الجباة.
- إظهار الحد المسموح والمستخدم والمتبقي.
- إضافة وتعديل بيانات الجابي.
- التفعيل والإيقاف والتعطيل.
- إدارة الصلاحيات.
- تغيير كلمة المرور.
- صفحة إدارة التخصيصات المرجعية.
- شاشة Collector تعرض تخصيصاته فقط.
- حفظ آخر قائمة جباة وتخصيصات ناجحة داخل SQLite عبر `app_meta` للعرض عند انقطاع الإنترنت.
- إظهار حالة الإنترنت داخل شاشات Owner وCollector.
- Logout يستدعي السيرفر عند توفر الإنترنت ثم يمسح Secure Storage محليًا دائمًا.
- لا توجد شاشة قراءة أو جباية أو فاتورة مالية.

## اختبارات Node المنفذة

```text
node --check src/modules/generators/generators.collectors.service.js
node --check src/modules/generators/generators.auth.service.js
node --check src/modules/generators/generators.auth.middleware.js
node --check src/modules/generators/generators.routes.js
node --test tests/generators_stage01.test.js tests/generators_stage02.test.js tests/generators_stage02_contract.test.js
```

النتيجة المحلية: 4 اختبارات ناجحة، 0 فشل.

الحالات المختبرة:

- عدم كسر مصادقة وعزل وIdempotency الخاصة بـStage01.
- إنشاء الجابي ضمن الحد.
- رفض تجاوز الحد.
- عزل مؤسستين.
- عدم تخزين كلمة المرور كنص صريح.
- رفض صلاحية غير مسموحة.
- إلغاء Refresh Token بعد تغيير الصلاحيات.
- عزل التخصيصات.
- منع دخول الحساب المعطل.
- تحرير مقعد عند التعطيل.
- رفض إعادة التفعيل عند امتلاء الحد.
- تغيير كلمة المرور وإلغاء الجلسات القديمة.
- وجود Audit Logs.

## فحوص Flutter

أضيف اختبار Model جديد، لكن بيئة التنفيذ المستخدمة لا تحتوي Flutter/Dart، لذلك لم يتم الادعاء بتشغيل `flutter analyze` أو `flutter test` أو بناء APK/AAB. يجب تشغيل `bootstrap_flutter.cmd` على جهاز Windows الذي يحتوي Flutter.

## ما لم ينفذ عمدًا

- لا مشتركين حقيقيين أو مولدات حقيقية في قاعدة البيانات حتى الآن.
- لا قراءة عداد.
- لا جباية كاملة أو جزئية.
- لا فواتير أو ديون أو مصاريف أو أرباح.
- لا برنامج حاسبة.
- لا GPS أو إشعارات أو طباعة أو واتساب.
- لا بناء iPhone على Windows.

## المرحلة التالية المقترحة

`Stage03 — Generators, Subscribers & Route Contracts`

تثبيت جداول المولدات والمشتركين والمسارات وعلاقاتها وتحقق التخصيصات داخل Tenant، دون فتح الجباية المالية قبل اعتماد العقود.
