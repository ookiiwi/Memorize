const fu = require('../utils/file-utils');
const path = require('path');
const fs = require('fs');

exports.search = (req, res, next) => {
    req.params.dir = '/shared/addon';
    fu.search(req,res,next);
};

exports.get = (req, res, next) => {
    const p = path.join(__dirname, '../storage/shared/addon/' + req.params.id);
    const file = fs.readFileSync(p).toString();
    res.status(200).json(file);
};