# تقرير Stage06 — Simple Payments

## النسخة الأساسية

- Base: `agent/generators-mobile-stage05-simple-clear-invoices`
- لا رجوع إلى Stage05/Stage06 المعقدتين.
- لا دمج في `main` ولا نشر على Render.

## ما تم تنفيذه

- زر **تسجيل دفعة** داخل بطاقة الفاتورة نفسها.
- عرض الإجمالي والمدفوع والمتبقي.
- حالات واضحة: غير مسددة، جزئي، مسددة.
- دفع نقد أو تحويل.
- رقم وصل لكل دفعة.
- سجل الدفعات يظهر تحت الفاتورة نفسها.
- منع الدفع الزائد وتكرار نفس العملية.
- لا دفتر ذمم، لا صندوق، ولا صفحة مالية ثانية.
- إصدار Flutter `0.6.0+6`.

## الفحص

```text
Node syntax check: passed
SQLite payment runtime: passed
50,000 payment -> remaining 73,000: passed
duplicate operation -> one receipt only: passed
73,000 final payment -> paid: passed
overpayment rejection: passed
Dart structure balance: passed
```

## غير منفذ

- لا طباعة وصل.
- لا صندوق أو إغلاق كاشير.
- لا إرجاع دفعة.
- لا تحصيل الجابي Offline.
