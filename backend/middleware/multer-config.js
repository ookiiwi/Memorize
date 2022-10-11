const multer = require('multer');
const mongoose = require('mongoose');
const fs = require('fs');
const { resolveUserstorage } =  require('../utils/file-utils');


const storage = multer.diskStorage({
    destination: (req, _, cb) => {
        cb(null, req.body.path);
    },
    filename: (req, _, cb) => {
        cb(null, req.params.id);
    }
});

const fileFilter = (req, file, cb) => {
    req.body.path = resolveUserstorage(req.body.path, req.auth.userId);

    if (!fs.existsSync(req.body.path)) {
        throw "File not found";
    }

    if (!req.params.id) {
        req.params.id = String(mongoose.Types.ObjectId());
    }
    
    cb(null, true);
};

module.exports = multer({
        storage: storage, 
        fileFilter: fileFilter
    }).single('file');