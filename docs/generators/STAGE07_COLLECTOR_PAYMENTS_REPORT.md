# تقرير Stage07 — Collector Online Payments

## النسخة الأساسية

- Base: `agent/generators-mobile-stage06-simple-payments`
- Commit الأساس: `e4489919cfc4afb9365bf950d3d60e3ee00cdf25`
- لا رجوع إلى مسارات المسودات أو دفتر الذمم.
- لا دمج في `main` ولا نشر على Render.

## ما تم تنفيذه

- صفحة **تحصيل الفواتير** للجابي.
- عرض الفواتير التابعة لتخصيصات الجابي فقط.
- بحث بالاسم أو الحساب أو العداد أو رقم الفاتورة أو الهاتف.
- دفع كامل أو جزئي بنقد أو تحويل.
- رقم وصل وتحديث المدفوع والمتبقي.
- إظهار اسم مستلم الدفعة لصاحب المولدة.
- حماية تخصيص المولدة والمسار والمشترك.
- منع UUID من الاستخدام على فاتورتين.
- إصدار Flutter `0.7.0+7`.

## الفحص

```text
Node syntax checks: passed
Assignment SQL runtime: passed
Collector A sees only assigned invoice: covered
Collector B cannot pay Collector A invoice: covered
50,000 payment -> partial / remaining 73,000: covered
Duplicate UUID -> same receipt: covered
UUID reused on another invoice -> conflict: covered
Owner sees collector receiver identity: covered
Dart structural checks: passed
```

## غير منفذ

- لا تحصيل Offline.
- لا طباعة وصل.
- لا صندوق أو تسوية جابي.
- لا إرجاع أو حذف دفعة.
- لا GPS أو واتساب أو إشعارات.
