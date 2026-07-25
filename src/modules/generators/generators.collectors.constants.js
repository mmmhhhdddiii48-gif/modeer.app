const COLLECTOR_PERMISSION_ALLOWLIST = Object.freeze([
  'assignments.read',
  'subscribers.assigned.read',
  'readings.create',
  'collections.create',
  'collections.own.read',
  'receipts.create',
  'sync.own.read'
]);

const DEFAULT_COLLECTOR_PERMISSIONS = Object.freeze([...COLLECTOR_PERMISSION_ALLOWLIST]);
const ASSIGNMENT_TYPES = new Set(['generator', 'subscriber', 'route']);

module.exports = { COLLECTOR_PERMISSION_ALLOWLIST, DEFAULT_COLLECTOR_PERMISSIONS, ASSIGNMENT_TYPES };
