# تدقيق السيرفر الحالي — وحدة المولدات Stage01

## النتيجة التنفيذية

المستودع الحالي Backend صغير ومنظم بـ Node.js وExpress ويعمل من `src/server.js`. قاعدة البيانات SQLite محلية باستخدام `node:sqlite` وملفها الافتراضي `data/nukhba.sqlite`، بينما Render يثبتها على `/var/data/nukhba.sqlite` عبر Persistent Disk. لا توجد ORM ولا migrations framework منفصلة؛ التهيئة الحالية تعتمد SQL idempotent عند بدء السيرفر.

## المسارات الحالية التي يجب حمايتها

- `GET /` و`GET /health`
- `POST /auth/login`
- `GET /auth/me`
- جميع `/manager/*`
- جميع `/employee/*`
- `src/db/schema.sql` والجداول الحالية: users, agents, system_settings, notifications, messages, daily_entries, location_updates, day_closures
- متغيرات Render الحالية، خصوصًا `DB_FILE` و`AUTH_TOKEN_SECRET`

## المصادقة الحالية

- كلمات المرور تستخدم scrypt مع توافق محدود مع SHA-256 القديم.
- التوكن الحالي HMAC مخصص لجمهور `nukhba-agent-app` وصلاحيته الافتراضية 8 ساعات.
- تطبيق الموظف محمي بـ Bearer Token.
- مسارات المدير الحالية لا تطبق middleware مصادقة في ملف routes. هذا خطر موجود مسبقًا ويجب علاجه بمرحلة مستقلة بعد فحص تطبيق المدير، وليس ضمن Stage01 حتى لا ينكسر التطبيق الحالي.

## قرار العزل

وحدة المولدات لا تعيد استخدام جدول `users` ولا توكن تطبيق الموظف. تمت إضافة جداول تبدأ بـ `generator_`، جمهور توكن مستقل `nukhba-generators-mobile`، ومسارات محصورة تحت `/generators/...`.

## مناطق ممنوع لمسها في Stage01

- منطق المدير والموظف الحالي.
- GPS الموجود للنظام السابق؛ لم تتم إضافته أو استعماله في تطبيق المولدات.
- Render Service وBase URL.
- برنامج الحاسبة أو أي ربط Desktop.
- التدفقات المالية الفعلية للقراءات والجبايات والفواتير.
