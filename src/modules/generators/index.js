const express = require('express');
const { generatorsRouter: stage06Router } = require('./generators.stage06.routes');
const { generatorsRouter: baseRouter } = require('./generators.routes');

const generatorsRouter = express.Router();
generatorsRouter.use(stage06Router);
generatorsRouter.use(baseRouter);

module.exports = { generatorsRouter };
