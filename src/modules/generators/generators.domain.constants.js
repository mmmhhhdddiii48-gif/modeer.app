const GENERATOR_STATUSES = Object.freeze(['active', 'inactive', 'maintenance']);
const ROUTE_STATUSES = Object.freeze(['active', 'inactive']);
const SUBSCRIBER_STATUSES = Object.freeze(['active', 'suspended', 'disconnected']);
const PHASE_TYPES = Object.freeze(['single', 'three', 'unknown']);
const ASSIGNMENT_TYPES = Object.freeze(['generator', 'route', 'subscriber']);

module.exports = { GENERATOR_STATUSES, ROUTE_STATUSES, SUBSCRIBER_STATUSES, PHASE_TYPES, ASSIGNMENT_TYPES };
