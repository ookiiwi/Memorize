const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const upload = require('../middleware/multer-config');

const fileCtrl = require('../controllers/file');

const authNoExcept = (req, _, next) => {
    req.params.authNoExcept = true;
    next();
};

router.get('/:id', authNoExcept, auth, fileCtrl.read);
router.put('/:id', authNoExcept, auth, fileCtrl.update);
router.post('/',   auth, upload, fileCtrl.create); // return id
router.delete('/', auth, fileCtrl.delete);

module.exports = router;