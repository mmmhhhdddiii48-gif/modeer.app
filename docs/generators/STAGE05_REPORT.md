# تقرير Stage05 — Monthly Billing Calculation Contract

## النسخة الأساسية

- Branch base: `agent/generators-mobile-stage04-meter-reading-offline`
- Stage04 commit: `8768782e08c4e2e3c7d9cdd198213e261fac161c`
- لا تغيير للمستودع أو Render Service أو Base URL.

## ما تم تنفيذه في السيرفر

- مخطط مستقل لتسعيرات المولدات ومسودات الفواتير الشهرية.
- تسعيرة مستقلة لكل مولدة ولكل دورة قراءة.
- الحساب بالدينار: الأمبير المتعاقد × سعر الأمبير + رسم ثابت.
- اشتراط قفل دورة القراءة قبل التسعير والتوليد.
- اشتراط تسعيرة لكل مولدة لديها قراءات مؤكدة.
- Snapshot كامل داخل كل مسودة.
- توليد Idempotent لا يكرر المسودات.
- قفل تعديل التسعيرة بعد وجود المسودات.
- حالات `draft / reviewed` فقط.
- Tenant Isolation وAudit Log.
- لا قبض أو دين أو وصل أو أثر على الصندوق.

## ملفات السيرفر الجديدة

- `src/modules/generators/generators.billing.schema.sql`
- `src/modules/generators/generators.billing.service.js`
- `tests/generators_stage05.test.js`
- `tests/generators_stage05_contract.test.js`
- `docs/generators/STAGE05_ARCHITECTURE.md`
- `docs/generators/STAGE05_API.md`
- `docs/generators/STAGE05_REPORT.md`

## ملفات السيرفر المعدلة

- `src/modules/generators/generators.routes.js`
- `src/modules/generators/generators.sync.service.js`
- `package.json`

## ما تم تنفيذه في Flutter

- Models للدورات والتسعيرات والمسودات والملخص.
- Billing API Client وRepository مع Cache داخل `app_meta`.
- شاشة صاحب المولدة لاختيار الدورة وضبط تسعيرة كل مولدة.
- زر توليد آمن مع تأكيد واضح بعدم وجود أثر مالي.
- عرض معادلة كل مسودة ولقطات القراءة والاستهلاك.
- تعليم المسودة كمراجعة أو إعادتها إلى Draft.
- ربط الشاشة بالواجهة الرئيسية لصاحب المولدة فقط.
- تحديث الإصدار إلى `0.5.0+5`.

## الاختبارات المنفذة

تم تشغيل Syntax Check لملفات Node الجديدة والمعدلة، وتشغيل Harness معزول يستخدم `node:sqlite` لخدمة Stage05.

```text
Stage05 runtime harness: 2 passed, 0 failed
Stage05 source contracts: 2 passed, 0 failed
```

الحالات المختبرة:

- رفض التوليد قبل التسعيرة.
- حساب 10 أمبير × 12,000 + 3,000 = 123,000 دينار.
- إعادة التوليد بدون تكرار.
- قفل التسعيرة بعد التوليد.
- تغيير حالة المراجعة وإعادتها.
- رفض التسعير قبل قفل الدورة.
- عزل مؤسسة ثانية.

تمت إضافة اختبارات المستودع الكاملة. يجب تشغيل:

```text
npm run test:generators
```

بعد سحب الفرع على جهاز التطوير أو عبر CI.

## فحوص Flutter

أضيف اختبار Models وتمت مراجعة بنية واستيرادات ملفات Dart نصيًا. بيئة التنفيذ لا تحتوي Flutter/Dart، لذلك يجب تشغيل:

```text
flutter analyze
flutter test
flutter build apk --release
```

على جهاز Windows يحتوي Flutter.

## ما لم ينفذ عمدًا

- لا تحصيل كامل أو جزئي.
- لا ديون أو ذمم.
- لا وصولات أو طباعة.
- لا تأثير على الصندوق.
- لا تعديل أو حذف مالي لمسودة.
- لا مصاريف أو وقود أو أرباح.
- لا GPS أو إشعارات أو واتساب.
- لا ربط برنامج الحاسبة.

## المرحلة التالية المقترحة

`Stage06 — Invoice Approval & Debt Ledger Contract`

تحويل المسودة المراجعة إلى فاتورة معتمدة وفتح الذمة بصورة مضبوطة، دون تحصيل قبل اعتماد عقد الدين والفاتورة.
