# API Stage02 — حسابات الجباة

جميع المسارات تحت `/generators`، وجميع مسارات Owner وCollector بعد تسجيل الدخول تحتاج Bearer Access Token.

| Method | Endpoint | الدور | الوظيفة |
|---|---|---|---|
| GET | `/owner/collectors` | owner | قائمة الجباة واستهلاك الحد |
| POST | `/owner/collectors` | owner | إنشاء حساب جابي |
| GET | `/owner/collectors/:collectorId` | owner | تفاصيل جابي داخل نفس المؤسسة |
| PATCH | `/owner/collectors/:collectorId` | owner | تعديل الاسم واسم المستخدم والهاتف |
| PATCH | `/owner/collectors/:collectorId/status` | owner | تفعيل أو إيقاف أو تعطيل |
| PUT | `/owner/collectors/:collectorId/permissions` | owner | استبدال صلاحيات الجابي ضمن Allowlist |
| POST | `/owner/collectors/:collectorId/reset-password` | owner | تعيين كلمة مرور جديدة وإلغاء الجلسات القديمة |
| GET | `/owner/collectors/:collectorId/assignments` | owner | قراءة تخصيصات الجابي |
| PUT | `/owner/collectors/:collectorId/assignments` | owner | استبدال التخصيصات المرجعية |
| GET | `/collector/assignments` | collector | مشاهدة تخصيصات الحساب الحالي فقط |

## مثال إنشاء جابي

```json
{
  "full_name": "اسم الجابي",
  "username": "collector.1",
  "phone": "07800000000",
  "password": "strong-password"
}
```

لا يسمح بتمرير `tenant_id` أو `role` أو `status` عند الإنشاء. الحساب ينشأ كـ`collector` و`active` داخل مؤسسة صاحب المولدة.

## مثال استبدال التخصيصات

```json
{
  "assignments": [
    {
      "type": "route",
      "target_id": "route-reference-1",
      "label": "مسار حي الأمير",
      "metadata": {}
    }
  ]
}
```

هذه المراجع ليس لها أثر مالي في Stage02.
