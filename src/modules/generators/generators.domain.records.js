const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema } = require('./generators.db');
const { cleanRequired, placeholders } = require('./generators.domain.validation');

function findGeneratorOrFail(tenantId, publicId) {
  const normalized = cleanRequired(publicId, 'generator_id', 80);
  const row = findGeneratorByPublicId(tenantId, normalized);
  if (!row) throw httpError(404, 'GENERATOR_UNIT_NOT_FOUND', 'Generator was not found in this organization.');
  return row;
}

function findGeneratorByPublicId(tenantId, publicId) {
  const db = ensureGeneratorsSchema();
  return db.prepare(`
    SELECT g.*,
      (SELECT COUNT(*) FROM generator_routes r WHERE r.tenant_id = g.tenant_id AND r.generator_unit_id = g.id) AS route_count,
      (SELECT COUNT(*) FROM generator_subscribers s WHERE s.tenant_id = g.tenant_id AND s.generator_unit_id = g.id) AS subscriber_count
    FROM generator_units g WHERE g.tenant_id = ? AND g.public_id = ? LIMIT 1
  `).get(Number(tenantId), publicId) || null;
}

function findGeneratorById(tenantId, id) {
  const db = ensureGeneratorsSchema();
  return db.prepare(`
    SELECT g.*,
      (SELECT COUNT(*) FROM generator_routes r WHERE r.tenant_id = g.tenant_id AND r.generator_unit_id = g.id) AS route_count,
      (SELECT COUNT(*) FROM generator_subscribers s WHERE s.tenant_id = g.tenant_id AND s.generator_unit_id = g.id) AS subscriber_count
    FROM generator_units g WHERE g.tenant_id = ? AND g.id = ? LIMIT 1
  `).get(Number(tenantId), Number(id)) || null;
}

function findRouteOrFail(tenantId, publicId) {
  const normalized = cleanRequired(publicId, 'route_id', 80);
  const row = findRouteByPublicId(tenantId, normalized);
  if (!row) throw httpError(404, 'GENERATOR_ROUTE_NOT_FOUND', 'Route was not found in this organization.');
  return row;
}

function findRouteByPublicId(tenantId, publicId) {
  const db = ensureGeneratorsSchema();
  return db.prepare(routeSelectSql('r.tenant_id = ? AND r.public_id = ?')).get(Number(tenantId), publicId) || null;
}

function findRouteById(tenantId, id) {
  const db = ensureGeneratorsSchema();
  return db.prepare(routeSelectSql('r.tenant_id = ? AND r.id = ?')).get(Number(tenantId), Number(id)) || null;
}

function routeSelectSql(where) {
  return `
    SELECT r.*, g.public_id AS generator_public_id, g.name AS generator_name,
      g.code AS generator_code, g.status AS generator_status,
      (SELECT COUNT(*) FROM generator_subscribers s WHERE s.tenant_id = r.tenant_id AND s.route_id = r.id) AS subscriber_count
    FROM generator_routes r
    LEFT JOIN generator_units g ON g.id = r.generator_unit_id AND g.tenant_id = r.tenant_id
    WHERE ${where}
    LIMIT 1
  `;
}

function findSubscriberOrFail(tenantId, publicId) {
  const normalized = cleanRequired(publicId, 'subscriber_id', 80);
  const row = findSubscriberByPublicId(tenantId, normalized);
  if (!row) throw httpError(404, 'GENERATOR_SUBSCRIBER_NOT_FOUND', 'Subscriber was not found in this organization.');
  return row;
}

function findSubscriberByPublicId(tenantId, publicId) {
  const db = ensureGeneratorsSchema();
  return db.prepare(subscriberSelectSql('s.tenant_id = ? AND s.public_id = ?')).get(Number(tenantId), publicId) || null;
}

function findSubscriberById(tenantId, id) {
  const db = ensureGeneratorsSchema();
  return db.prepare(subscriberSelectSql('s.tenant_id = ? AND s.id = ?')).get(Number(tenantId), Number(id)) || null;
}

function subscriberSelectSql(where) {
  return `
    SELECT s.*,
      g.public_id AS generator_public_id, g.name AS generator_name, g.code AS generator_code, g.status AS generator_status,
      r.public_id AS route_public_id, r.name AS route_name, r.code AS route_code, r.status AS route_status
    FROM generator_subscribers s
    JOIN generator_units g ON g.id = s.generator_unit_id AND g.tenant_id = s.tenant_id
    LEFT JOIN generator_routes r ON r.id = s.route_id AND r.tenant_id = s.tenant_id
    WHERE ${where}
    LIMIT 1
  `;
}

function listCatalogGenerators(tenantId, q) {
  const db = ensureGeneratorsSchema();
  const args = [Number(tenantId)];
  const search = q ? 'AND (code LIKE ? OR name LIKE ? OR area LIKE ?)' : '';
  if (q) args.push(`%${q}%`, `%${q}%`, `%${q}%`);
  return db.prepare(`
    SELECT * FROM generator_units
    WHERE tenant_id = ? AND status = 'active' ${search}
    ORDER BY name COLLATE NOCASE LIMIT 500
  `).all(...args).map((row) => ({ id: row.public_id, type: 'generator', code: row.code, label: row.name, area: row.area, status: row.status }));
}

function listCatalogRoutes(tenantId, q) {
  const db = ensureGeneratorsSchema();
  const args = [Number(tenantId)];
  const search = q ? 'AND (r.code LIKE ? OR r.name LIKE ? OR r.area LIKE ?)' : '';
  if (q) args.push(`%${q}%`, `%${q}%`, `%${q}%`);
  return db.prepare(`
    SELECT r.*, g.public_id AS generator_public_id, g.name AS generator_name
    FROM generator_routes r
    LEFT JOIN generator_units g ON g.id = r.generator_unit_id AND g.tenant_id = r.tenant_id
    WHERE r.tenant_id = ? AND r.status = 'active' ${search}
    ORDER BY r.name COLLATE NOCASE LIMIT 500
  `).all(...args).map((row) => ({
    id: row.public_id,
    type: 'route',
    code: row.code,
    label: row.name,
    area: row.area,
    status: row.status,
    generator_id: row.generator_public_id || null,
    generator_name: row.generator_name || null
  }));
}

function listCatalogSubscribers(tenantId, q) {
  const db = ensureGeneratorsSchema();
  const args = [Number(tenantId)];
  const search = q ? 'AND (s.account_number LIKE ? OR s.full_name LIKE ? OR s.phone LIKE ? OR s.area LIKE ?)' : '';
  if (q) args.push(`%${q}%`, `%${q}%`, `%${q}%`, `%${q}%`);
  return db.prepare(`
    SELECT s.*, g.public_id AS generator_public_id, g.name AS generator_name,
      r.public_id AS route_public_id, r.name AS route_name
    FROM generator_subscribers s
    JOIN generator_units g ON g.id = s.generator_unit_id AND g.tenant_id = s.tenant_id
    LEFT JOIN generator_routes r ON r.id = s.route_id AND r.tenant_id = s.tenant_id
    WHERE s.tenant_id = ? AND s.status = 'active' ${search}
    ORDER BY s.full_name COLLATE NOCASE LIMIT 1000
  `).all(...args).map((row) => ({
    id: row.public_id,
    type: 'subscriber',
    code: row.account_number,
    label: row.full_name,
    phone: row.phone,
    area: row.area,
    status: row.status,
    generator_id: row.generator_public_id,
    generator_name: row.generator_name,
    route_id: row.route_public_id || null,
    route_name: row.route_name || null
  }));
}

function selectAssignedSubscribers(db, tenantId, directSubscribers, directRoutes, directGenerators) {
  const conditions = [];
  const args = [Number(tenantId)];
  if (directSubscribers.size) {
    conditions.push(`s.public_id IN (${placeholders(directSubscribers.size)})`);
    args.push(...directSubscribers);
  }
  if (directRoutes.size) {
    conditions.push(`r.public_id IN (${placeholders(directRoutes.size)})`);
    args.push(...directRoutes);
  }
  if (directGenerators.size) {
    conditions.push(`g.public_id IN (${placeholders(directGenerators.size)})`);
    args.push(...directGenerators);
  }
  if (!conditions.length) return [];
  return db.prepare(`
    SELECT s.*,
      g.public_id AS generator_public_id, g.name AS generator_name, g.code AS generator_code, g.status AS generator_status,
      r.public_id AS route_public_id, r.name AS route_name, r.code AS route_code, r.status AS route_status
    FROM generator_subscribers s
    JOIN generator_units g ON g.id = s.generator_unit_id AND g.tenant_id = s.tenant_id
    LEFT JOIN generator_routes r ON r.id = s.route_id AND r.tenant_id = s.tenant_id
    WHERE s.tenant_id = ? AND (${conditions.join(' OR ')})
    ORDER BY s.full_name COLLATE NOCASE
  `).all(...args);
}

function selectRoutesForGenerators(db, tenantId, generatorPublicIds) {
  if (!generatorPublicIds.size) return [];
  return db.prepare(`
    SELECT r.*, g.public_id AS generator_public_id, g.name AS generator_name,
      g.code AS generator_code, g.status AS generator_status,
      (SELECT COUNT(*) FROM generator_subscribers s WHERE s.tenant_id = r.tenant_id AND s.route_id = r.id) AS subscriber_count
    FROM generator_routes r
    JOIN generator_units g ON g.id = r.generator_unit_id AND g.tenant_id = r.tenant_id
    WHERE r.tenant_id = ? AND g.public_id IN (${placeholders(generatorPublicIds.size)})
    ORDER BY r.name COLLATE NOCASE
  `).all(Number(tenantId), ...generatorPublicIds);
}

function selectDomainRoutes(db, tenantId, publicIds) {
  if (!publicIds.size) return [];
  return db.prepare(`
    SELECT r.*, g.public_id AS generator_public_id, g.name AS generator_name,
      g.code AS generator_code, g.status AS generator_status,
      (SELECT COUNT(*) FROM generator_subscribers s WHERE s.tenant_id = r.tenant_id AND s.route_id = r.id) AS subscriber_count
    FROM generator_routes r
    LEFT JOIN generator_units g ON g.id = r.generator_unit_id AND g.tenant_id = r.tenant_id
    WHERE r.tenant_id = ? AND r.public_id IN (${placeholders(publicIds.size)})
    ORDER BY r.name COLLATE NOCASE
  `).all(Number(tenantId), ...publicIds);
}

function selectDomainGenerators(db, tenantId, publicIds) {
  if (!publicIds.size) return [];
  return db.prepare(`
    SELECT g.*,
      (SELECT COUNT(*) FROM generator_routes r WHERE r.tenant_id = g.tenant_id AND r.generator_unit_id = g.id) AS route_count,
      (SELECT COUNT(*) FROM generator_subscribers s WHERE s.tenant_id = g.tenant_id AND s.generator_unit_id = g.id) AS subscriber_count
    FROM generator_units g
    WHERE g.tenant_id = ? AND g.public_id IN (${placeholders(publicIds.size)})
    ORDER BY g.name COLLATE NOCASE
  `).all(Number(tenantId), ...publicIds);
}

function serializeGenerator(row) {
  return {
    id: row.public_id,
    code: row.code,
    name: row.name,
    area: row.area,
    address: row.address,
    capacity_kva: row.capacity_kva == null ? null : Number(row.capacity_kva),
    phase_type: row.phase_type,
    status: row.status,
    notes: row.notes,
    route_count: Number(row.route_count || 0),
    subscriber_count: Number(row.subscriber_count || 0),
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function serializeRoute(row) {
  return {
    id: row.public_id,
    code: row.code,
    name: row.name,
    area: row.area,
    status: row.status,
    notes: row.notes,
    generator: row.generator_public_id ? {
      id: row.generator_public_id,
      code: row.generator_code,
      name: row.generator_name,
      status: row.generator_status
    } : null,
    subscriber_count: Number(row.subscriber_count || 0),
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

function serializeSubscriber(row) {
  return {
    id: row.public_id,
    account_number: row.account_number,
    full_name: row.full_name,
    phone: row.phone,
    area: row.area,
    address: row.address,
    meter_number: row.meter_number,
    contracted_amperes: Number(row.contracted_amperes || 0),
    status: row.status,
    notes: row.notes,
    generator: {
      id: row.generator_public_id,
      code: row.generator_code,
      name: row.generator_name,
      status: row.generator_status
    },
    route: row.route_public_id ? {
      id: row.route_public_id,
      code: row.route_code,
      name: row.route_name,
      status: row.route_status
    } : null,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}

module.exports = {
  findGeneratorOrFail,
  findGeneratorByPublicId,
  findGeneratorById,
  findRouteOrFail,
  findRouteByPublicId,
  findRouteById,
  routeSelectSql,
  findSubscriberOrFail,
  findSubscriberByPublicId,
  findSubscriberById,
  subscriberSelectSql,
  listCatalogGenerators,
  listCatalogRoutes,
  listCatalogSubscribers,
  selectAssignedSubscribers,
  selectRoutesForGenerators,
  selectDomainRoutes,
  selectDomainGenerators,
  serializeGenerator,
  serializeRoute,
  serializeSubscriber,
};
