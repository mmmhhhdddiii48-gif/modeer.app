# نشر Nukhba Backend على GitHub + Render

## 1) قبل الرفع إلى GitHub

تأكد أن هذا المجلد يحتوي على:

- `package.json`
- `package-lock.json`
- `src/`
- `scripts/`
- `.gitignore`
- `.env.example`
- `.env.render.example`
- `render.yaml`

لا ترفع ملف `.env` الحقيقي ولا قاعدة SQLite المحلية داخل `data/`.

## 2) رفع المشروع إلى GitHub

من داخل هذا المجلد:

```bash
git init
git add .
git commit -m "Prepare Nukhba backend for Render"
git branch -M main
git remote add origin https://github.com/YOUR_USER/YOUR_REPO.git
git push -u origin main
```

## 3) النشر على Render بالطريقة الموصى بها

الأفضل لهذا المشروع في هذه المرحلة هو Web Service مع Persistent Disk لأن المشروع يستخدم SQLite.

إعدادات Render:

- Build Command: `npm install`
- Start Command: `npm run start`
- Health Check Path: `/health`
- Environment: Node
- Node version: `22.16.0` أو أعلى

Environment Variables:

```text
NODE_ENV=production
HOST=0.0.0.0
DB_FILE=/var/data/nukhba.sqlite
CORS_ORIGIN=*
AUTH_TOKEN_SECRET=ضع_قيمة_طويلة_سرية
AUTH_TOKEN_EXPIRES_IN=8h
```

Disk:

```text
Mount path: /var/data
Size: 1 GB أو أكثر
```

## 4) عنوان الـ API النهائي

بعد نجاح النشر سيظهر لك رابط مثل:

```text
https://nukhba-api.onrender.com
```

هذا الرابط هو الذي تضعه داخل تطبيق المدير وتطبيق الموظف في ملف:

```text
api-config.json
```

مثال:

```json
{
  "apiBaseUrl": "https://nukhba-api.onrender.com"
}
```

## 5) ملاحظات مهمة

- إذا استخدمت Render Free بدون Persistent Disk، البيانات المحلية داخل SQLite قد تضيع عند redeploy أو restart.
- للاستخدام الفعلي مع SQLite، استخدم Render paid web service + persistent disk.
- مستقبلًا، يمكن نقل قاعدة البيانات إلى PostgreSQL إذا احتجت توسع أقوى.
