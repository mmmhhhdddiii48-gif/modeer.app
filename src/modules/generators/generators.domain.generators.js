const crypto = require('node:crypto');
const { ensureGeneratorsSchema } = require('./generators.db');
const { getDomainSummary } = require('./generators.domain.assignments.service');
const { GENERATOR_STATUSES } = require('./generators.domain.constants');
const { normalizeGeneratorInput } = require('./generators.domain.inputs');
const { findGeneratorOrFail, findGeneratorById, serializeGenerator } = require('./generators.domain.records');
const { addStatusFilter, addSearchFilter, auditEntity, assertOwner, normalizeEnum, normalizeDomainWriteError } = require('./generators.domain.validation');

function listOwnerGenerators(auth, query = {}) {
  assertOwner(auth);
  const db = ensureGeneratorsSchema();
  const filters = ['g.tenant_id = ?'];
  const args = [auth.tenantId];
  addStatusFilter(filters, args, query.status, GENERATOR_STATUSES, 'g.status');
  addSearchFilter(filters, args, query.q, ['g.code', 'g.name', 'g.area', 'g.address']);
  const rows = db.prepare(`
    SELECT g.*,
      (SELECT COUNT(*) FROM generator_routes r WHERE r.tenant_id = g.tenant_id AND r.generator_unit_id = g.id) AS route_count,
      (SELECT COUNT(*) FROM generator_subscribers s WHERE s.tenant_id = g.tenant_id AND s.generator_unit_id = g.id) AS subscriber_count
    FROM generator_units g
    WHERE ${filters.join(' AND ')}
    ORDER BY CASE g.status WHEN 'active' THEN 0 WHEN 'maintenance' THEN 1 ELSE 2 END,
      g.name COLLATE NOCASE
    LIMIT 500
  `).all(...args);
  return { generators: rows.map(serializeGenerator), summary: getDomainSummary(auth.tenantId) };
}

function getOwnerGenerator(auth, generatorPublicId) {
  assertOwner(auth);
  return serializeGenerator(findGeneratorOrFail(auth.tenantId, generatorPublicId));
}

function createOwnerGenerator(auth, body) {
  assertOwner(auth);
  const input = normalizeGeneratorInput(body, null);
  const db = ensureGeneratorsSchema();
  const publicId = crypto.randomUUID();
  try {
    const result = db.prepare(`
      INSERT INTO generator_units (
        public_id, tenant_id, code, name, area, address,
        capacity_kva, phase_type, status, notes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      publicId,
      auth.tenantId,
      input.code,
      input.name,
      input.area,
      input.address,
      input.capacity_kva,
      input.phase_type,
      input.status,
      input.notes
    );
    const created = findGeneratorById(auth.tenantId, Number(result.lastInsertRowid));
    auditEntity(auth, 'generator.domain.generator_created', 'generator_unit', publicId, null, serializeGenerator(created));
    return serializeGenerator(created);
  } catch (error) {
    throw normalizeDomainWriteError(error, 'GENERATOR_CODE_EXISTS', 'A generator with this code already exists in this organization.');
  }
}

function updateOwnerGenerator(auth, generatorPublicId, body) {
  assertOwner(auth);
  const current = findGeneratorOrFail(auth.tenantId, generatorPublicId);
  const input = normalizeGeneratorInput(body, current);
  const db = ensureGeneratorsSchema();
  try {
    db.prepare(`
      UPDATE generator_units
      SET code = ?, name = ?, area = ?, address = ?, capacity_kva = ?,
        phase_type = ?, notes = ?
      WHERE id = ? AND tenant_id = ?
    `).run(
      input.code,
      input.name,
      input.area,
      input.address,
      input.capacity_kva,
      input.phase_type,
      input.notes,
      current.id,
      auth.tenantId
    );
  } catch (error) {
    throw normalizeDomainWriteError(error, 'GENERATOR_CODE_EXISTS', 'A generator with this code already exists in this organization.');
  }
  const updated = findGeneratorById(auth.tenantId, current.id);
  auditEntity(auth, 'generator.domain.generator_updated', 'generator_unit', current.public_id, serializeGenerator(current), serializeGenerator(updated));
  return serializeGenerator(updated);
}

function updateOwnerGeneratorStatus(auth, generatorPublicId, body) {
  assertOwner(auth);
  const current = findGeneratorOrFail(auth.tenantId, generatorPublicId);
  const status = normalizeEnum(body?.status, 'status', GENERATOR_STATUSES, current.status);
  const db = ensureGeneratorsSchema();
  db.prepare('UPDATE generator_units SET status = ? WHERE id = ? AND tenant_id = ?')
    .run(status, current.id, auth.tenantId);
  const updated = findGeneratorById(auth.tenantId, current.id);
  auditEntity(auth, 'generator.domain.generator_status_updated', 'generator_unit', current.public_id, { status: current.status }, { status });
  return serializeGenerator(updated);
}

module.exports = {
  listOwnerGenerators,
  getOwnerGenerator,
  createOwnerGenerator,
  updateOwnerGenerator,
  updateOwnerGeneratorStatus,
};
