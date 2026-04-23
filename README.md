# Nukhba API Backend - Render Ready

Backend API مركزي لتطبيق المدير وتطبيق الموظف.

## التشغيل المحلي

```bash
npm install
npm run db:init
npm run check:db
npm run start
```

## النشر على Render

راجع:

```text
README_DEPLOY_GITHUB_RENDER.md
```

## Render files

- `render.yaml`: إعداد موصى به مع Persistent Disk.
- `render.free-demo.yaml`: إعداد تجريبي مجاني بدون حفظ دائم للبيانات.
- `.env.render.example`: متغيرات البيئة المطلوبة في Render.

## Health check

```text
GET /health
```

## API الأساسي

- `POST /auth/login`
- `GET /auth/me`
- `/manager/*`
- `/employee/*`
