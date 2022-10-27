const express = require('express');
const router = express.Router();

const dictCtrl = require('../controllers/dict');

router.get('/', dictCtrl.find);
router.get('/:id', dictCtrl.get);

module.exports = router;