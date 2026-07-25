# تقرير Stage03 — Generators, Subscribers & Route Contracts

## النسخة الأساسية

- Branch base: `agent/generators-mobile-stage02-owner-collectors`
- Stage02 commit: `26e46e5603c92e81cbdd3f6f2b870783f65e86c8`
- لا تغيير للمستودع أو Render Service أو Base URL.

## ما تم تنفيذه في السيرفر

- جداول حقيقية للمولدات والمسارات والمشتركين داخل SQLite الحالية.
- Tenant Isolation في كل قراءة وكتابة وعلاقة.
- إنشاء وعرض وتعديل وتغيير حالة المولدات.
- إنشاء وعرض وتعديل وتغيير حالة المسارات.
- إنشاء وعرض وبحث وتعديل وتغيير حالة المشتركين.
- تحقق أن المسار تابع للمولدة المختارة.
- منع نقل مسار مرتبط بمشتركين بطريقة تكسر البيانات.
- أرقام حسابات وأكواد وأرقام عدادات فريدة داخل المؤسسة.
- كتالوج أهداف حقيقية لتخصيصات الجباة.
- تحقق Server-Side من كل تخصيص واشتقاق الاسم والـmetadata من القاعدة.
- عرض Domain الجابي ضمن نطاق تكليفه فقط.
- Audit Log لجميع عمليات الإنشاء والتعديل والحالة.
- لا حذف صلب ولا أثر مالي.

## ملفات السيرفر الجديدة

- `src/modules/generators/generators.domain.service.js`
- `src/modules/generators/generators.domain.constants.js`
- `src/modules/generators/generators.domain.validation.js`
- `src/modules/generators/generators.domain.records.js`
- `src/modules/generators/generators.domain.inputs.js`
- `src/modules/generators/generators.domain.generators.js`
- `src/modules/generators/generators.domain.routes.service.js`
- `src/modules/generators/generators.domain.subscribers.service.js`
- `src/modules/generators/generators.domain.assignments.service.js`
- `tests/generators_stage03.test.js`
- `tests/generators_stage03_contract.test.js`
- `docs/generators/STAGE03_ARCHITECTURE.md`
- `docs/generators/STAGE03_API.md`
- `docs/generators/STAGE03_REPORT.md`

## ملفات السيرفر المعدلة

- `src/modules/generators/generators.schema.sql`
- `src/modules/generators/generators.collectors.service.js`
- `src/modules/generators/generators.collectors.constants.js`
- `src/modules/generators/generators.collectors.records.js`
- `src/modules/generators/generators.collectors.management.js`
- `src/modules/generators/generators.collectors.assignments.js`
- `src/modules/generators/generators.routes.js`
- `src/modules/generators/generators.sync.service.js`
- `tests/generators_stage01.test.js`
- `tests/generators_stage02.test.js`
- `tests/generators_stage02_contract.test.js`
- `package.json`

## ما تم تنفيذه في Flutter

- Models للمولدات والمسارات والمشتركين وكتالوج التخصيصات.
- Domain Repository يربط API مع SQLite cache.
- واجهة موبايل بثلاثة تبويبات لإدارة المولدات والمسارات والمشتركين.
- إضافة وتعديل وتغيير حالة السجلات.
- البحث وعرض العلاقات بشكل مناسب للموبايل.
- استبدال إدخال معرف التخصيص اليدوي باختيار هدف حقيقي من كتالوج السيرفر.
- شاشة الجابي تعرض المشتركين والمسارات والمولدات المكلف بها فقط.
- حفظ آخر Domain مؤكد محليًا للعرض عند انقطاع الإنترنت.
- بقاء مؤشر الاتصال والمزامنة اليدوية.

## اختبارات Node المنفذة

```text
node --check src/modules/generators/generators.domain.service.js
node --check src/modules/generators/generators.collectors.service.js
node --check src/modules/generators/generators.routes.js
node --check src/modules/generators/generators.sync.service.js
node --test tests/generators_stage01.test.js tests/generators_stage02.test.js tests/generators_stage02_contract.test.js tests/generators_stage03.test.js tests/generators_stage03_contract.test.js
```

النتيجة المحلية: **8 اختبارات ناجحة، 0 فشل**.

الحالات تشمل:

- عدم كسر Stage01 وStage02.
- عزل مؤسستين في المولدات والمسارات والمشتركين.
- تحقق علاقات المولدة والمسار والمشترك.
- رفض الأهداف غير الموجودة أو التابعة لمؤسسة أخرى.
- منع تزوير اسم أو metadata التخصيص من الواجهة.
- عرض الجابي للمشتركين ضمن نطاق تكليفه فقط.
- بقاء العمليات المالية والقراءات مقفلة.

## فحوص Flutter

بيئة التنفيذ لا تحتوي Flutter/Dart، لذلك لم يتم الادعاء بتشغيل `flutter analyze` أو `flutter test` أو بناء APK/AAB. تمت مراجعة عقود الملفات ومراجع الاستيراد نصيًا، ويجب تشغيل `bootstrap_flutter.cmd` على Windows يحتوي Flutter.

## ما لم ينفذ عمدًا

- لا قراءات عدادات.
- لا دورة شهرية أو تسعير أمبير.
- لا جباية كاملة أو جزئية.
- لا فواتير أو ديون أو وصولات.
- لا مصاريف أو وقود أو صيانة مالية أو أرباح.
- لا GPS أو إشعارات أو طباعة أو واتساب.
- لا ربط برنامج الحاسبة.
- لا بناء iPhone على Windows.

## المرحلة التالية المقترحة

`Stage04 — Meter Reading Offline Contract`

تثبيت دورة قراءة العداد Offline-First، UUID وIdempotency والتعارض وقواعد الإغلاق الشهري، دون فتح التحصيل المالي قبل اعتماد القراءة والفاتورة.
