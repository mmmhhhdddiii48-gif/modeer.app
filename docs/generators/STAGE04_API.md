# API Stage04 — دورات وقراءات العدادات

جميع المسارات تحت `/generators` وتحتاج Bearer Access Token بعد تسجيل الدخول.

| Method | Endpoint | الدور | الوظيفة |
|---|---|---|---|
| GET | `/owner/reading-periods` | owner | عرض دورات القراءة |
| POST | `/owner/reading-periods` | owner | فتح دورة شهرية |
| PATCH | `/owner/reading-periods/:periodId/lock` | owner | قفل الدورة بتأكيد صريح |
| GET | `/owner/meter-readings?period_id=...&q=...` | owner | عرض قراءات الدورة وملخصها |
| GET | `/collector/readings/context` | collector | الدورة المفتوحة والمشتركون المكلف بهم والقراءة السابقة |
| POST | `/sync/operations` | owner/collector | إرسال عمليات المزامنة، ومنها `reading.create` للجابي |
| GET | `/sync/status` | owner/collector | أعداد applied/conflict/rejected وآخر استلام |

## فتح دورة

```json
{
  "period_key": "2026-07",
  "title": "دورة تموز 2026"
}
```

لا يسمح بفتح دورة ثانية قبل قفل الدورة المفتوحة.

## قفل دورة

```json
{
  "confirm": true
}
```

القفل يمنع القراءات الجديدة فقط ولا يولد فاتورة في Stage04.

## إرسال قراءة Offline

```json
{
  "operation_uuid": "4e1b9cc0-2d51-4a3c-9c8d-1518ed8a5a70",
  "operation_type": "reading.create",
  "client_created_at": "2026-07-25T12:00:00.000Z",
  "payload": {
    "period_id": "period-public-id",
    "subscriber_id": "subscriber-public-id",
    "previous_value": 150,
    "current_value": 175,
    "note": "قراءة ميدانية"
  }
}
```

## حالات نتيجة المزامنة

- `applied`: ثبتت القراءة.
- `conflict`: تحتاج مراجعة، مثل تغيّر السابقة أو وجود قراءة سابقة.
- `rejected`: رفضت بسبب قفل الدورة أو عدم التكليف أو بيانات غير صالحة.
- `received`: عملية أساس غير مالية مثل `sync.probe`.

التحصيل والفواتير غير مسموحين؛ `collection.create` وأي عملية غير معتمدة ترفض بـ`STAGE04_OPERATION_NOT_ENABLED`.
