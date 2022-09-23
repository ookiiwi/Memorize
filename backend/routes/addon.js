const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const upload = require('../middleware/multer-config');

router.use((req, res, next) => {
    req.params.dest = 'addon';
    next();
});

router.post('/', auth, upload);
router.get('/:id', auth, listCtrl.get);
router.put('/:id', auth, upload, listCtrl.update);

module.exports = router;