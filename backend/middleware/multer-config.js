const multer = require('multer');
const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
const { resolveUserstorage } =  require('../utils/file-utils');


const storage = multer.diskStorage({
    destination: (req, _, cb) => {
        cb(null, req.body.dest);
    },
    filename: (req, _, cb) => {
        cb(null, req.params.id);
    }
});

const fileFilter = (req, file, cb) => {
    req.body.dest = resolveUserstorage(req.body.dest, req.auth.userId);
    req.body.dest = path.join(__dirname, '../storage' + req.body.dest);

    if (!fs.existsSync(req.body.dest)) {
        console.log('mkdir: ' + req.body.dest);
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