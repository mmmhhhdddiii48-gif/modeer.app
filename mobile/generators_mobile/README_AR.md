# النخبة لإدارة المولدات والجباية Mobile — Stage01

هذا المشروع هو أساس Flutter مستقل لتطبيق Android وiPhone بكود واحد. المرحلة الحالية تحتوي شاشة افتتاحية، شاشة تسجيل دخول، تخزين توكنات آمن، قاعدة SQLite محلية، وبنية Queue للمزامنة Offline-First.

## الثوابت

- Base URL: `https://modeer-app.onrender.com`
- وحدة السيرفر: `/generators/...`
- لا يوجد تسجيل ذاتي.
- لا يوجد GPS أو تتبع موقع.
- الوظائف المالية غير مفعلة في Stage01.

## تجهيز Android وiOS على Windows

1. ثبّت Flutter Stable وAndroid Studio وفعّل Android SDK.
2. من هذا المجلد شغّل:

```text
bootstrap_flutter.cmd
```

الملف ينشئ مجلدي `android` و`ios` من Flutter الرسمي، يثبت Android minSdk على 24، ثم ينفذ:

```text
flutter pub get
flutter analyze
flutter test
```

## التشغيل

```bash
flutter run
```

## بناء Android

```bash
flutter build apk --release
flutter build appbundle --release
```

## iPhone

كود iOS ومجلده يجهزان من البداية، لكن البناء والتوقيع والفحص الفعلي يجب أن يتم لاحقًا على Mac مع Xcode. لا تعتبر نسخة iPhone مفحوصة من Windows.

## ملاحظات الأمان

- Access Token وRefresh Token يحفظان في `flutter_secure_storage` وليس SQLite.
- SQLite مخصصة للكاش وQueue والحركات المحلية.
- لا توجد مفاتيح سرية داخل Flutter.
- السيرفر هو المسؤول عن الصلاحيات وعزل المؤسسات.
- الحركة المحلية لا تحذف بعد المزامنة؛ تتغير حالتها إلى `synced` بعد تأكيد السيرفر.
