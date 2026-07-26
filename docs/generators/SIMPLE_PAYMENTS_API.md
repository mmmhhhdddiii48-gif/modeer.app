# API — التسديد البسيط داخل الفاتورة

جميع المسارات تحت `/generators` وتحتاج حساب صاحب المولدة وصلاحية `invoices.manage`.

| Method | Endpoint | الوظيفة |
|---|---|---|
| POST | `/owner/monthly-billing/invoices/:invoiceId/payments` | تسجيل دفعة على الفاتورة |

## الطلب

```json
{
  "confirm": true,
  "operation_uuid": "UUID",
  "amount_iqd": 50000,
  "payment_method": "cash",
  "note": "اختياري"
}
```

طرق الدفع الحالية: `cash` أو `transfer`.

الاستجابة تعيد رقم الوصل وحالة الفاتورة والمبلغ المدفوع والمتبقي. لا توجد API لدفتر ذمم منفصل أو صندوق أو حذف دفعة.
