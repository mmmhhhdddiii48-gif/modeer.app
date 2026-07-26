const { httpError } = require('../../utils/httpError');
const { ensureGeneratorsSchema } = require('./generators.db');
const { GENERATOR_STATUSES, ROUTE_STATUSES, SUBSCRIBER_STATUSES, PHASE_TYPES } = require('./generators.domain.constants');
const { normalizeCode, normalizeEnum, nullableNumber, nonNegativeInteger, cleanRequired, cleanOptional } = require('./generators.domain.validation');
const { findGeneratorOrFail, findGeneratorByPublicId, findRouteOrFail, findRouteByPublicId } = require('./generators.domain.records');

function normalizeGeneratorInput(body, current) {
  return {
    code: body?.code === undefined && current ? current.code : normalizeCode(body?.code, 'code'),
    name: body?.name === undefined && current ? current.name : cleanRequired(body?.name, 'name', 160),
    area: body?.area === undefined && current ? current.area : cleanOptional(body?.area, 160),
    address: body?.address === undefined && current ? current.address : cleanOptional(body?.address, 300),
    capacity_kva: body?.capacity_kva === undefined && current ? nullableNumber(current.capacity_kva, 'capacity_kva') : nullableNumber(body?.capacity_kva, 'capacity_kva'),
    phase_type: body?.phase_type === undefined && current ? current.phase_type : normalizeEnum(body?.phase_type ?? 'unknown', 'phase_type', PHASE_TYPES),
    status: current ? current.status : normalizeEnum(body?.status ?? 'active', 'status', GENERATOR_STATUSES),
    notes: body?.notes === undefined && current ? current.notes : cleanOptional(body?.notes, 1000)
  };
}

function normalizeRouteInput(body, current, tenantId) {
  const generatorPublicId = body?.generator_id === undefined && current
    ? current.generator_public_id
    : cleanOptional(body?.generator_id, 80);
  const generator = generatorPublicId ? findGeneratorOrFail(tenantId, generatorPublicId) : null;
  return {
    generator_unit_id: generator ? Number(generator.id) : null,
    code: body?.code === undefined && current ? current.code : normalizeCode(body?.code, 'code'),
    name: body?.name === undefined && current ? current.name : cleanRequired(body?.name, 'name', 160),
    area: body?.area === undefined && current ? current.area : cleanOptional(body?.area, 160),
    notes: body?.notes === undefined && current ? current.notes : cleanOptional(body?.notes, 1000),
    status: current ? current.status : normalizeEnum(body?.status ?? 'active', 'status', ROUTE_STATUSES)
  };
}

function normalizeSubscriberInput(body, current, tenantId) {
  const generatorPublicId = body?.generator_id === undefined && current
    ? current.generator_public_id
    : cleanRequired(body?.generator_id, 'generator_id', 80);
  const routePublicId = body?.route_id === undefined && current
    ? current.route_public_id
    : cleanOptional(body?.route_id, 80);
  const generator = findGeneratorOrFail(tenantId, generatorPublicId);
  const route = routePublicId ? findRouteOrFail(tenantId, routePublicId) : null;
  if (route?.generator_unit_id && Number(route.generator_unit_id) !== Number(generator.id)) {
    throw httpError(409, 'GENERATOR_ROUTE_MISMATCH', 'The selected route belongs to a different generator.');
  }
  return {
    generator_unit_id: Number(generator.id),
    route_id: route ? Number(route.id) : null,
    account_number: body?.account_number === undefined && current ? current.account_number : normalizeCode(body?.account_number, 'account_number'),
    full_name: body?.full_name === undefined && current ? current.full_name : cleanRequired(body?.full_name, 'full_name', 160),
    phone: body?.phone === undefined && current ? current.phone : cleanOptional(body?.phone, 40),
    area: body?.area === undefined && current ? current.area : cleanOptional(body?.area, 160),
    address: body?.address === undefined && current ? current.address : cleanOptional(body?.address, 300),
    meter_number: body?.meter_number === undefined && current ? current.meter_number : cleanOptional(body?.meter_number, 100),
    contracted_amperes: body?.contracted_amperes === undefined && current
      ? nonNegativeInteger(current.contracted_amperes, 'contracted_amperes')
      : nonNegativeInteger(body?.contracted_amperes ?? 0, 'contracted_amperes'),
    status: current ? current.status : normalizeEnum(body?.status ?? 'active', 'status', SUBSCRIBER_STATUSES),
    notes: body?.notes === undefined && current ? current.notes : cleanOptional(body?.notes, 1000)
  };
}

function assertRouteGeneratorChangeSafe(tenantId, routeId, newGeneratorUnitId) {
  if (newGeneratorUnitId == null) return;
  const db = ensureGeneratorsSchema();
  const mismatch = db.prepare(`
    SELECT COUNT(*) AS count
    FROM generator_subscribers
    WHERE tenant_id = ? AND route_id = ? AND generator_unit_id != ?
  `).get(Number(tenantId), Number(routeId), Number(newGeneratorUnitId));
  if (Number(mismatch.count || 0) > 0) {
    throw httpError(409, 'GENERATOR_ROUTE_IN_USE', 'This route has subscribers linked to another generator and cannot be moved.');
  }
}

module.exports = {
  normalizeGeneratorInput,
  normalizeRouteInput,
  normalizeSubscriberInput,
  assertRouteGeneratorChangeSafe,
};
