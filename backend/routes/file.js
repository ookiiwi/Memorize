const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const upload = require('../middleware/multer-config');

const fileCtrl = require('../controllers/file');

const authNoExcept = (req, _, next) => {
    req.params.authNoExcept = true;
    next();
};

router.get('/search',   authNoExcept, auth, fileCtrl.search);
router.get('/',         authNoExcept, auth, fileCtrl.read);
router.put('/',         authNoExcept, auth, upload, fileCtrl.update);
router.delete('/', auth, fileCtrl.delete);

module.exports = router;