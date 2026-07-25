const crypto = require('node:crypto');
const { ensureGeneratorsSchema } = require('./generators.db');
const { getDomainSummary } = require('./generators.domain.assignments.service');
const { SUBSCRIBER_STATUSES } = require('./generators.domain.constants');
const { normalizeSubscriberInput } = require('./generators.domain.inputs');
const { findSubscriberOrFail, findSubscriberById, serializeSubscriber } = require('./generators.domain.records');
const { addStatusFilter, addSearchFilter, auditEntity, assertOwner, normalizeEnum, cleanRequired, normalizeSubscriberWriteError } = require('./generators.domain.validation');

function listOwnerSubscribers(auth, query = {}) {
  assertOwner(auth);
  const db = ensureGeneratorsSchema();
  const filters = ['s.tenant_id = ?'];
  const args = [auth.tenantId];
  addStatusFilter(filters, args, query.status, SUBSCRIBER_STATUSES, 's.status');
  addSearchFilter(filters, args, query.q, ['s.account_number', 's.full_name', 's.phone', 's.area', 's.address', 's.meter_number']);
  if (query.generator_id) {
    filters.push('g.public_id = ?');
    args.push(cleanRequired(query.generator_id, 'generator_id', 80));
  }
  if (query.route_id) {
    filters.push('r.public_id = ?');
    args.push(cleanRequired(query.route_id, 'route_id', 80));
  }
  const rows = db.prepare(`
    SELECT s.*,
      g.public_id AS generator_public_id, g.name AS generator_name, g.code AS generator_code, g.status AS generator_status,
      r.public_id AS route_public_id, r.name AS route_name, r.code AS route_code, r.status AS route_status
    FROM generator_subscribers s
    JOIN generator_units g ON g.id = s.generator_unit_id AND g.tenant_id = s.tenant_id
    LEFT JOIN generator_routes r ON r.id = s.route_id AND r.tenant_id = s.tenant_id
    WHERE ${filters.join(' AND ')}
    ORDER BY CASE s.status WHEN 'active' THEN 0 WHEN 'suspended' THEN 1 ELSE 2 END,
      s.full_name COLLATE NOCASE
    LIMIT 1000
  `).all(...args);
  return { subscribers: rows.map(serializeSubscriber), summary: getDomainSummary(auth.tenantId) };
}

function getOwnerSubscriber(auth, subscriberPublicId) {
  assertOwner(auth);
  return serializeSubscriber(findSubscriberOrFail(auth.tenantId, subscriberPublicId));
}

function createOwnerSubscriber(auth, body) {
  assertOwner(auth);
  const input = normalizeSubscriberInput(body, null, auth.tenantId);
  const db = ensureGeneratorsSchema();
  const publicId = crypto.randomUUID();
  try {
    const result = db.prepare(`
      INSERT INTO generator_subscribers (
        public_id, tenant_id, generator_unit_id, route_id, account_number,
        full_name, phone, area, address, meter_number, contracted_amperes,
        status, notes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      publicId,
      auth.tenantId,
      input.generator_unit_id,
      input.route_id,
      input.account_number,
      input.full_name,
      input.phone,
      input.area,
      input.address,
      input.meter_number,
      input.contracted_amperes,
      input.status,
      input.notes
    );
    const created = findSubscriberById(auth.tenantId, Number(result.lastInsertRowid));
    auditEntity(auth, 'generator.domain.subscriber_created', 'generator_subscriber', publicId, null, serializeSubscriber(created));
    return serializeSubscriber(created);
  } catch (error) {
    throw normalizeSubscriberWriteError(error);
  }
}

function updateOwnerSubscriber(auth, subscriberPublicId, body) {
  assertOwner(auth);
  const current = findSubscriberOrFail(auth.tenantId, subscriberPublicId);
  const input = normalizeSubscriberInput(body, current, auth.tenantId);
  const db = ensureGeneratorsSchema();
  try {
    db.prepare(`
      UPDATE generator_subscribers
      SET generator_unit_id = ?, route_id = ?, account_number = ?, full_name = ?,
        phone = ?, area = ?, address = ?, meter_number = ?, contracted_amperes = ?, notes = ?
      WHERE id = ? AND tenant_id = ?
    `).run(
      input.generator_unit_id,
      input.route_id,
      input.account_number,
      input.full_name,
      input.phone,
      input.area,
      input.address,
      input.meter_number,
      input.contracted_amperes,
      input.notes,
      current.id,
      auth.tenantId
    );
  } catch (error) {
    throw normalizeSubscriberWriteError(error);
  }
  const updated = findSubscriberById(auth.tenantId, current.id);
  auditEntity(auth, 'generator.domain.subscriber_updated', 'generator_subscriber', current.public_id, serializeSubscriber(current), serializeSubscriber(updated));
  return serializeSubscriber(updated);
}

function updateOwnerSubscriberStatus(auth, subscriberPublicId, body) {
  assertOwner(auth);
  const current = findSubscriberOrFail(auth.tenantId, subscriberPublicId);
  const status = normalizeEnum(body?.status, 'status', SUBSCRIBER_STATUSES, current.status);
  const db = ensureGeneratorsSchema();
  db.prepare('UPDATE generator_subscribers SET status = ? WHERE id = ? AND tenant_id = ?')
    .run(status, current.id, auth.tenantId);
  const updated = findSubscriberById(auth.tenantId, current.id);
  auditEntity(auth, 'generator.domain.subscriber_status_updated', 'generator_subscriber', current.public_id, { status: current.status }, { status });
  return serializeSubscriber(updated);
}

module.exports = {
  listOwnerSubscribers,
  getOwnerSubscriber,
  createOwnerSubscriber,
  updateOwnerSubscriber,
  updateOwnerSubscriberStatus,
};
