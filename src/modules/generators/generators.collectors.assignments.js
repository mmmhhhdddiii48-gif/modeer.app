const crypto = require('node:crypto');
const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema, writeAuditLog } = require('./generators.db');
const { findOwnedCollectorOrFail, serializeCollector, normalizeAssignments, listAssignmentsForCollector, assertOwner } = require('./generators.collectors.records');

function listOwnerCollectorAssignments(auth, collectorPublicId) {
  assertOwner(auth);
  const collector = findOwnedCollectorOrFail(auth.tenantId, collectorPublicId);
  return {
    collector: serializeCollector(collector),
    assignments: listAssignmentsForCollector(auth.tenantId, collector.id)
  };
}

function replaceOwnerCollectorAssignments(auth, collectorPublicId, body) {
  assertOwner(auth);
  const collector = findOwnedCollectorOrFail(auth.tenantId, collectorPublicId);
  const assignments = normalizeAssignments(body?.assignments, auth.tenantId);
  const db = ensureGeneratorsSchema();
  const before = listAssignmentsForCollector(auth.tenantId, collector.id);

  db.exec('BEGIN IMMEDIATE');
  try {
    db.prepare(`
      UPDATE generator_collector_assignments
      SET status = 'inactive'
      WHERE tenant_id = ? AND collector_account_id = ? AND status = 'active'
    `).run(auth.tenantId, collector.id);

    const upsert = db.prepare(`
      INSERT INTO generator_collector_assignments (
        public_id, tenant_id, collector_account_id, assignment_type,
        target_public_id, target_label, metadata_json, status, assigned_by_account_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'active', ?)
      ON CONFLICT(tenant_id, collector_account_id, assignment_type, target_public_id)
      DO UPDATE SET
        target_label = excluded.target_label,
        metadata_json = excluded.metadata_json,
        status = 'active',
        assigned_by_account_id = excluded.assigned_by_account_id,
        updated_at = datetime('now')
    `);

    for (const assignment of assignments) {
      upsert.run(
        crypto.randomUUID(),
        auth.tenantId,
        collector.id,
        assignment.type,
        assignment.target_id,
        assignment.label,
        JSON.stringify(assignment.metadata),
        auth.accountId
      );
    }
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }

  const after = listAssignmentsForCollector(auth.tenantId, collector.id);
  writeAuditLog({
    tenantId: auth.tenantId,
    actorAccountId: auth.accountId,
    action: 'generator.collector.assignments_replaced',
    entityType: 'generator_collector_assignments',
    entityUuid: collector.public_id,
    before,
    after
  });
  return { collector: serializeCollector(collector), assignments: after };
}

function listCollectorOwnAssignments(auth) {
  if (!auth || auth.role !== 'collector') {
    throw httpError(403, 'GENERATOR_PERMISSION_DENIED', 'Collector account is required.');
  }
  return {
    collector_id: auth.accountPublicId,
    assignments: listAssignmentsForCollector(auth.tenantId, auth.accountId)
  };
}

module.exports = {
  listOwnerCollectorAssignments,
  replaceOwnerCollectorAssignments,
  listCollectorOwnAssignments,
};
