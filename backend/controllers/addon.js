const fu = require('../utils/file-utils');

exports.search = (req, res, next) => {
    req.params.dir = '/public/addon';
    fu.search(req,res,next);
};

exports.get = (req,res,next) => {};