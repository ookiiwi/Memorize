const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');

const directoryCtrl = require('../controllers/directory');

router.get('/',     auth, directoryCtrl.ls);
router.put('/',     auth, directoryCtrl.update);
router.post('/',    auth, directoryCtrl.mkdir);
router.delete('/',  auth, directoryCtrl.delete);

module.exports = router;