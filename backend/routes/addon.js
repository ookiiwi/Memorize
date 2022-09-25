const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const upload = require('../middleware/multer-config');
const addonCtrl = require('../controllers/addon');

router.use((req, res, next) => {
    req.params.dest = 'addon';
    next();
});

router.get('/', addonCtrl.search); // list all addons available or matching names if search query param
router.get('/:id', addonCtrl.get); // return an addon
router.post('/', auth, upload);
router.put('/:id', auth, upload);

module.exports = router;