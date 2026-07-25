# معمارية Stage01 — النخبة لإدارة المولدات والجباية Mobile

## مخطط قاعدة البيانات المقترح والمنفذ كأساس

### generator_tenants
مؤسسة صاحب المولدة: الاسم، الهاتف، الحالة، مدة الاشتراك، وعدد الجباة المسموح.

### generator_accounts
حسابات `owner` و`collector` مع tenant_id إلزامي، وكلمات مرور Hash وصلاحيات JSON. يوجد نوع `platform_admin` للمستقبل فقط ولا يسمح له بدخول تطبيق الموبايل.

### generator_refresh_tokens
Refresh Tokens مخزنة Hash فقط، مع انتهاء وصلاحية وإلغاء وتدوير Token Rotation.

### generator_sync_operations
سجل Idempotency لكل Tenant باستخدام القيد الفريد `(tenant_id, operation_uuid)`. يحفظ UUID ونوع العملية وHash المحتوى ووقت الإنشاء المحلي ووقت الاستلام من السيرفر والحالة.

### generator_audit_logs
سجل تدقيق للحركات والتعديلات مع actor وtenant ووقت السيرفر ووقت العميل إن وجد.

## API Endpoints في Stage01

| Method | Endpoint | الحماية | الحالة |
|---|---|---|---|
| GET | `/generators/health` | عام | منفذ |
| POST | `/generators/auth/login` | عام | منفذ |
| POST | `/generators/auth/refresh` | Refresh Token | منفذ |
| POST | `/generators/auth/logout` | Refresh Token | منفذ |
| GET | `/generators/auth/me` | Access Token | منفذ |
| GET | `/generators/owner/foundation` | owner | منفذ كأساس فقط |
| GET | `/generators/collector/foundation` | collector | منفذ كأساس فقط |
| POST | `/generators/sync/operations` | owner/collector | منفذ لاختبارات `sync.probe` فقط |
| GET | `/generators/sync/status` | owner/collector | منفذ |

لا توجد Endpoints للتسجيل الذاتي أو إنشاء الجباة أو القراءات أو الجبايات المالية في Stage01.

## مخطط الصلاحيات

### مالك النظام Platform Admin
ينشئ أصحاب المولدات ويدير الاشتراكات من لوحة خاصة مستقبلًا. لا يدخل تطبيق الموبايل بهذا الدور.

### صاحب المولدة Owner
يرتبط بـ Tenant واحد. صلاحياته المخططة تشمل الإدارة والتقارير والجباة والمصاريف، لكن Stage01 يثبت الهوية والصلاحيات فقط.

### الجابي Collector
يرتبط بـ Tenant واحد، ويجب أن يرى التخصيصات والحركات الخاصة به فقط. لا أرباح ولا مصاريف كاملة ولا إعدادات إدارة.

قرار من ينشئ حساب الجابي غير مثبت، لذلك لم يضف أي Endpoint لإنشائه.

## مخطط المزامنة Offline/Online

1. التطبيق ينشئ UUID للعملية ويحفظها في SQLite بحالة `pending`.
2. تبقى الحركة محليًا عند انقطاع الإنترنت.
3. عند رجوع الشبكة يحاول Sync Engine الإرسال بالترتيب.
4. السيرفر يعزل العملية حسب tenant المستخرج من التوكن، وليس tenant مرسل من الواجهة.
5. إذا وصل UUID لأول مرة يسجل `server_received_at` ويرد بالتأكيد.
6. إذا أعيد نفس UUID ونفس المحتوى يعيد نفس النتيجة كـ duplicate آمن.
7. إذا أعيد UUID بمحتوى مختلف يرد `IDEMPOTENCY_CONFLICT` ولا يستبدل الأصل.
8. التطبيق لا يحذف السجل المحلي؛ يغير حالته إلى `synced` بعد تأكيد السيرفر.
9. وقت الجهاز يحفظ كـ client_created_at للمعلومة، أما القرار المالي مستقبلًا فيعتمد وقت السيرفر وقواعده.

## حدود Stage01

العملية الوحيدة المسموحة للمزامنة هي `sync.probe` و`auth.session_seen`. أي عملية مالية ترفض برسالة `STAGE01_OPERATION_NOT_ENABLED` حتى تثبيت العقود وقاعدة البيانات النهائية.
