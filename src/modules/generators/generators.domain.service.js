const constants = require('./generators.domain.constants');
const generators = require('./generators.domain.generators');
const routes = require('./generators.domain.routes.service');
const subscribers = require('./generators.domain.subscribers.service');
const assignments = require('./generators.domain.assignments.service');

module.exports = { ...constants, ...generators, ...routes, ...subscribers, ...assignments };
