const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const upload = require('../middleware/multer-config');

const listCtrl = require('../controllers/list');

router.use((req, res, next) => {
    req.params.dest = 'list';
    next();
});

router.post('/', auth, upload, listCtrl.upload);
router.get('/', listCtrl.search); // returns all public lists or searched lists
router.get('/:id', listCtrl.get); // TODO: require auth for private lists
router.put('/:id', auth, upload, listCtrl.update);

module.exports = router;