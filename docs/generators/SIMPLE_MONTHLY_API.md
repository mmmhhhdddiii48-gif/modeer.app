# API — النسخة الواضحة لفواتير الشهر

جميع المسارات تحت `/generators` وتحتاج حساب صاحب المولدة وصلاحية `invoices.manage`.

| Method | Endpoint | الوظيفة |
|---|---|---|
| GET | `/owner/monthly-billing/periods` | عرض أشهر القراءات |
| GET | `/owner/monthly-billing/periods/:periodId` | عرض الأسعار والفواتير |
| PUT | `/owner/monthly-billing/periods/:periodId/generators/:generatorId/price` | حفظ سعر الأمبير |
| POST | `/owner/monthly-billing/periods/:periodId/create-invoices` | إنشاء فواتير الشهر مباشرة |

## إنشاء الفواتير

```json
{ "confirm": true }
```

الحساب:

```text
عدد الأمبيرات × سعر الأمبير + الرسم الثابت
```

لا توجد مسارات للمسودات أو المراجعة أو الاعتماد أو دفتر ذمم منفصل أو القبض.
