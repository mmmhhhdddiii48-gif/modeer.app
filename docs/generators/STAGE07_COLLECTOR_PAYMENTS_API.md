# API — تحصيل الجابي Online

جميع المسارات تحت `/generators` وتحتاج Bearer Token لحساب الجابي.

| Method | Endpoint | الوظيفة |
|---|---|---|
| GET | `/collector/collections/invoices?q=...` | عرض الفواتير التابعة لتخصيصات الجابي |
| POST | `/collector/collections/invoices/:invoiceId/payments` | تسجيل دفعة وإصدار رقم وصل |

## تسجيل دفعة

```json
{
  "confirm": true,
  "operation_uuid": "UUID",
  "amount_iqd": 50000,
  "payment_method": "cash",
  "note": "اختياري"
}
```

صلاحيات العرض: `collections.own.read` و`subscribers.assigned.read`.

صلاحيات الدفع: `collections.create` و`receipts.create`.

السيرفر يطابق الفاتورة مع تخصيص الجابي على مستوى المولدة أو المسار أو المشترك. لا يقبل `tenant_id` أو تخصيصًا من Body. التحصيل Online فقط ولا يوجد Queue مالي محلي.
