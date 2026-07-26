# API Stage03 — Generators, Subscribers & Routes

جميع المسارات أدناه تحت `/generators` وتحتاج Access Token بعد مسارات المصادقة.

## صاحب المولدة — المولدات

| Method | Endpoint | الصلاحية |
|---|---|---|
| GET | `/owner/generators` | `generators.manage` |
| POST | `/owner/generators` | `generators.manage` |
| GET | `/owner/generators/:generatorId` | `generators.manage` |
| PATCH | `/owner/generators/:generatorId` | `generators.manage` |
| PATCH | `/owner/generators/:generatorId/status` | `generators.manage` |

## صاحب المولدة — المسارات

| Method | Endpoint | الصلاحية |
|---|---|---|
| GET | `/owner/routes` | `generators.manage` |
| POST | `/owner/routes` | `generators.manage` |
| GET | `/owner/routes/:routeId` | `generators.manage` |
| PATCH | `/owner/routes/:routeId` | `generators.manage` |
| PATCH | `/owner/routes/:routeId/status` | `generators.manage` |

يمكن استخدام `generator_id` كفلتر في قائمة المسارات.

## صاحب المولدة — المشتركين

| Method | Endpoint | الصلاحية |
|---|---|---|
| GET | `/owner/subscribers` | `subscribers.manage` |
| POST | `/owner/subscribers` | `subscribers.manage` |
| GET | `/owner/subscribers/:subscriberId` | `subscribers.manage` |
| PATCH | `/owner/subscribers/:subscriberId` | `subscribers.manage` |
| PATCH | `/owner/subscribers/:subscriberId/status` | `subscribers.manage` |

فلاتر القائمة: `q`, `generator_id`, `route_id`, `status`.

## كتالوج التخصيصات

| Method | Endpoint | الصلاحية |
|---|---|---|
| GET | `/owner/assignment-catalog?type=generator|route|subscriber` | `collectors.manage` |

يعيد أهدافًا حقيقية قابلة للاختيار. عند حفظ تخصيصات الجابي يتحقق السيرفر مرة أخرى من الهدف ولا يعتمد على بيانات الواجهة.

## الجابي

| Method | Endpoint | الصلاحية |
|---|---|---|
| GET | `/collector/assignments` | `assignments.read` |
| GET | `/collector/domain` | `assignments.read` و`subscribers.assigned.read` |

`/collector/domain` يعيد فقط المولدات والمسارات والمشتركين الذين تقع ضمن نطاق تكليف الجابي.

## عمليات غير موجودة عمدًا

لا توجد Endpoints لقراءة العداد أو إنشاء الجباية أو الفاتورة أو الدين أو المصروف في Stage03. إرسال هذه الأنواع إلى Queue السيرفر يرفض بـ`STAGE03_OPERATION_NOT_ENABLED`.
