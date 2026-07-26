part of 'owner_home_page.dart';

final class _ConnectionStrip extends StatelessWidget {
  const _ConnectionStrip({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppTheme.teal : AppTheme.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 18, color: color),
          const SizedBox(width: 7),
          Text(online ? 'متصل — المزامنة متاحة' : 'بدون إنترنت — البيانات المحلية محفوظة'),
        ],
      ),
    );
  }
}

final class _OwnerHeader extends StatelessWidget {
  const _OwnerHeader({required this.session});
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.teal,
            child: Icon(Icons.electrical_services, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(session.tenantName, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _UsagePanel extends StatelessWidget {
  const _UsagePanel({required this.usage});
  final CollectorUsage usage;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _UsageChip(label: 'المسموح', value: usage.limit, icon: Icons.group_outlined),
        _UsageChip(label: 'المستخدم', value: usage.usedSlots, icon: Icons.badge_outlined),
        _UsageChip(label: 'المتبقي', value: usage.remainingSlots, icon: Icons.person_add_alt),
        _UsageChip(label: 'الفعال', value: usage.activeCount, icon: Icons.check_circle_outline),
      ],
    );
  }
}

final class _UsageChip extends StatelessWidget {
  const _UsageChip({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.teal),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }
}

final class _CollectorCard extends StatelessWidget {
  const _CollectorCard({
    required this.collector,
    required this.onEdit,
    required this.onPermissions,
    required this.onResetPassword,
    required this.onAssignments,
    required this.onStatus,
  });

  final CollectorAccount collector;
  final VoidCallback onEdit;
  final VoidCallback onPermissions;
  final VoidCallback onResetPassword;
  final VoidCallback onAssignments;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor(collector.status).withValues(alpha: 0.16),
                  child: Icon(Icons.person_outline, color: _statusColor(collector.status)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(collector.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text('@${collector.username}${collector.phone == null ? '' : ' • ${collector.phone}'}', style: const TextStyle(color: Colors.white60)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'permissions':
                        onPermissions();
                        break;
                      case 'password':
                        onResetPassword();
                        break;
                      case 'assignments':
                        onAssignments();
                        break;
                      case 'active':
                      case 'suspended':
                      case 'disabled':
                        onStatus(value);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
                    PopupMenuItem(value: 'permissions', child: Text('الصلاحيات')),
                    PopupMenuItem(value: 'assignments', child: Text('التخصيصات')),
                    PopupMenuItem(value: 'password', child: Text('تغيير كلمة المرور')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'active', child: Text('تفعيل الحساب')),
                    PopupMenuItem(value: 'suspended', child: Text('إيقاف مؤقت')),
                    PopupMenuItem(value: 'disabled', child: Text('تعطيل الحساب')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusBadge(status: collector.status),
                const SizedBox(width: 8),
                Text('التخصيصات: ${collector.assignmentCount}'),
                const Spacer(),
                Text(
                  collector.lastServerSyncAt == null
                      ? 'لا توجد مزامنة'
                      : 'آخر مزامنة: ${_formatDate(collector.lastServerSyncAt!)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) => switch (status) {
        'active' => AppTheme.teal,
        'suspended' => AppTheme.orange,
        _ => Colors.redAccent,
      };

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

final class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppTheme.teal,
      'suspended' => AppTheme.orange,
      _ => Colors.redAccent,
    };
    final label = switch (status) {
      'active' => 'فعال',
      'suspended' => 'موقوف مؤقتًا',
      _ => 'معطل',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
    );
  }
}

final class _EmptyCollectors extends StatelessWidget {
  const _EmptyCollectors();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.group_off_outlined, size: 44, color: Colors.white38),
          SizedBox(height: 10),
          Text('لا توجد حسابات جباة حتى الآن.'),
        ],
      ),
    );
  }
}
