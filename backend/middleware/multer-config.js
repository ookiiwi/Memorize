const multer = require('multer');
const mongoose = require('mongoose');

const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'lists/' + req.params.folder);
    },
    filename: (req, file, cb) => {
        cb(null, req.params.id);
    }
});

const fileFilter = (req, file, cb) => {
    
    if (req.body.status === 'private'){
        req.params.folder = 'private';
    } else {
        // TODO: check if allowed
        req.params.folder = 'public';
    }

    if (!req.params.id) 
    {
        console.log('set param');
        req.params.id = String(mongoose.Types.ObjectId());
    }
    
    cb(null, true);

    console.log(req.body.status);
};

module.exports = multer({
        storage: storage, 
        fileFilter: fileFilter
    }).single('list');