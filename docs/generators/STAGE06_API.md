# API Stage06 — الفواتير المعتمدة والذمم

جميع المسارات تحت `/generators` وتحتاج Bearer Access Token وصلاحية `invoices.manage` لصاحب المولدة.

| Method | Endpoint | الوظيفة |
|---|---|---|
| POST | `/owner/billing/drafts/:draftId/approve` | اعتماد المسودة وفتح الذمة |
| GET | `/owner/invoices?period_id=...&q=...` | عرض الفواتير والملخص |
| GET | `/owner/debt-ledger?subscriber_id=...&invoice_id=...&q=...` | عرض سجل الذمم |

## اعتماد فاتورة

```json
{
  "confirm": true
}
```

الاستجابة تتضمن `invoice`, `debt_entry`, `duplicate`, وحقولًا صريحة بأن القبض والوصل والصندوق غير مفعلة.

## عمليات غير موجودة عمدًا

لا توجد Endpoints للقبض أو التسديد الجزئي أو الوصل أو تعديل الذمة. إرسال `collection.create` إلى Queue يرفض بـ`STAGE06_OPERATION_NOT_ENABLED`.
