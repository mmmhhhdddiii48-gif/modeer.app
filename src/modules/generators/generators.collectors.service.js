const constants = require('./generators.collectors.constants');
const management = require('./generators.collectors.management');
const assignments = require('./generators.collectors.assignments');
const records = require('./generators.collectors.records');

module.exports = {
  ...constants,
  ...management,
  ...assignments,
  getCollectorUsage: records.getCollectorUsage
};
