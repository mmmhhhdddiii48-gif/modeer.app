# تقرير Stage01 — Server Audit & Mobile Foundation

## ما تم فحصه

- نقطة تشغيل Node.js وExpress.
- إعدادات البيئة وRender وPersistent SQLite.
- schema الحالية والجداول والعلاقات.
- مصادقة الموظف والتوكن وكلمات المرور.
- مسارات manager وemployee ومناطق الحماية.

## ملفات السيرفر الجديدة

- `src/modules/generators/index.js`
- `src/modules/generators/generators.routes.js`
- `src/modules/generators/generators.schema.sql`
- `src/modules/generators/generators.db.js`
- `src/modules/generators/generators.token.js`
- `src/modules/generators/generators.auth.service.js`
- `src/modules/generators/generators.auth.middleware.js`
- `src/modules/generators/generators.sync.service.js`
- `scripts/seed-generators-stage01.js`
- `tests/generators_stage01.test.js`

## ملفات السيرفر المعدلة

- `src/app.js`: تركيب `/generators` فقط.
- `package.json`: إضافة أوامر اختبار وSeed للوحدة.

## مشروع Flutter الجديد

المسار: `mobile/generators_mobile`

يتضمن:

- شاشة افتتاحية وشاشة دخول RTL.
- ثيم نخبة داكن تركواز/برتقالي.
- API Client على Base URL الثابت.
- Secure Storage للتوكنات.
- SQLite محلية.
- Sync Queue وUUID وAutomatic Retry foundation مع زر مزامنة يدوي.
- طبقات auth/core/database/network/sync/owner/collector.
- اختبارات نماذج أولية.
- Bootstrap رسمي لإنشاء مجلدي Android وiOS على Windows دون بناء iPhone.

## الاختبارات المنفذة

تم تشغيل Node.js syntax checks وNode test بنجاح للحالات التالية:

- إنشاء مؤسستين منفصلتين.
- تسجيل دخول Owner لكل مؤسسة.
- اختلاف tenant claims ومنع الخلط.
- تدوير Refresh Token ورفض إعادة استخدام التوكن القديم.
- قبول UUID أول مرة.
- إعادة نفس UUID ونفس المحتوى بدون تكرار.
- رفض نفس UUID بمحتوى مختلف.
- السماح بنفس UUID في Tenant آخر بسبب العزل.
- رفض أي عملية مالية في Stage01 قبل تثبيت عقدها.

## ما لم ينفذ عمدًا

- لا جباية مالية ولا فواتير ولا قراءات فعلية.
- لا إنشاء حسابات جباة؛ القرار ما زال ينتظر تثبيت المالك.
- لا لوحة Platform Admin كاملة.
- لا ربط برنامج الحاسبة.
- لا GPS ولا إشعارات ولا طباعة ولا واتساب.
- لا Build فعلي لـ iPhone على Windows.

## المرحلة التالية المقترحة

Stage02 بعد اعتماد Stage01: تثبيت قرار إنشاء حساب الجابي، ثم Admin Provisioning API/Panel وعقود المشتركين والمولدات والتخصيصات قبل أي جباية مالية.
