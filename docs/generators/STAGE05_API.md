# API Stage05 — Monthly Billing Drafts

جميع المسارات تحت `/generators` وتحتاج Bearer Access Token. جميع مسارات Stage05 خاصة بصاحب المولدة وصلاحية `invoices.manage`.

| Method | Endpoint | الوظيفة |
|---|---|---|
| GET | `/owner/billing/periods` | قائمة دورات القراءة مع ملخص التسعيرات والمسودات |
| GET | `/owner/billing/periods/:periodId` | Workspace الدورة: المولدات والتسعيرات والمسودات والملخص |
| PUT | `/owner/billing/periods/:periodId/tariffs/:generatorId` | إنشاء أو تعديل تسعيرة مولدة قبل التوليد |
| POST | `/owner/billing/periods/:periodId/generate` | توليد المسودات بصورة آمنة وغير مكررة |
| PATCH | `/owner/billing/drafts/:draftId/status` | تغيير الحالة بين `draft` و`reviewed` |

## مثال حفظ التسعيرة

```json
{
  "price_per_amp_iqd": 12000,
  "fixed_fee_iqd": 3000
}
```

## قاعدة المبلغ

```text
amount_iqd = contracted_amperes_snapshot × price_per_amp_iqd_snapshot + fixed_fee_iqd_snapshot
```

## حالات الرفض المهمة

- `BILLING_PERIOD_NOT_LOCKED`
- `BILLING_GENERATOR_HAS_NO_READINGS`
- `BILLING_TARIFF_MISSING`
- `BILLING_TARIFF_LOCKED_BY_DRAFTS`
- `BILLING_NO_CONFIRMED_READINGS`
- `BILLING_PERIOD_NOT_FOUND`
- `BILLING_DRAFT_NOT_FOUND`
- `INVALID_BILLING_MONEY_VALUE`
- `INVALID_BILLING_DRAFT_STATUS`

## ما لا يوجد عمدًا

لا توجد Endpoints للتحصيل أو الديون أو الوصولات أو الدفع أو فتح الصندوق. `collection.create` ما زالت مرفوضة من Queue المزامنة.
