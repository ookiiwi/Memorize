const multer = require('multer');
const mongoose = require('mongoose');
const fs = require('fs');
const { resolveUserstorage } = require('../utils/file-utils');


const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
    req.body.path = resolveUserstorage(req.body.path, req.auth.userId);

    cb(null, true);
};

module.exports = multer({
    storage: storage,
    fileFilter: fileFilter
}).single('file');