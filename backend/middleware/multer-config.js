const multer = require('multer');
const mongoose = require('mongoose');

const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, '/storage/' + req.params.status + '/' + req.params.dest);
    },
    filename: (req, _, cb) => {
        cb(null, req.params.id);
    }
});

const fileFilter = (req, file, cb) => {
    
    if (req.body.status === 'private'){
        // TODO: check if allowed
        req.params.status = 'private';
    } else {
        req.params.status = 'public';
    }

    if (!req.params.id) 
    {
        req.params.id = String(mongoose.Types.ObjectId());
    }
    
    cb(null, true);
};

module.exports = multer({
        storage: storage, 
        fileFilter: fileFilter
    }).single('file');