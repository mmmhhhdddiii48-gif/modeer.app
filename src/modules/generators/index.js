const express = require('express');
const { generatorsRouter: baseGeneratorsRouter } = require('./generators.routes');
const { simpleBillingRouter } = require('./generators.simple_billing.routes');

const generatorsRouter = express.Router();
generatorsRouter.use(simpleBillingRouter);
generatorsRouter.use(baseGeneratorsRouter);

module.exports = { generatorsRouter };
