const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');

const directoryCtrl = require('../controllers/directory');

router.put('/', auth, directoryCtrl.update);
router.post('/', auth, directoryCtrl.mkdir);
router.post('/ls', auth, directoryCtrl.ls);

module.exports = router;