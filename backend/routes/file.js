const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');

const fileCtrl = require('../controllers/file');

router.delete('/', auth, fileCtrl.delete);

module.exports = router;