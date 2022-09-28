const fu = require('../utils/file-utils');
const path = require('path');
const fs = require('fs');

const User = require('../models/user');

exports.search = (req, res, next) => {
    req.params.dir = '/shared/addon';
    fu.search(req,res,next);
};

exports.get = (req, res, next) => {
    const p = path.join(__dirname, '../storage/shared/addon/' + req.params.id);
    const file = fs.readFileSync(p).toString();
    res.status(200).json(file);
};

exports.getSchema = (req, res, next) => {
    User.findById(req.auth.userId).then(
        (user) => {
            const schema = user.addon_schema;
            res.status(201).json({ schema });
        }
    ).catch((err) => { 
        console.log(err);
        res.status(404).json({ err });
    });
};

exports.updateSchema = (req, res, next) => {
    User.findById(req.auth.userId).then(
        (user) => {
            user.addon_schema = req.body.schema;
            user.save();
        } 
    ).catch((err) => { 
        console.log(err);
        res.status(404).json({ err });
    });
};

exports.updateAddon = (req, res, next) => {
    const newName = req.query.name;

    if (newName){
        const oldPath = path.join(__dirname, '../storage/shared/addon/' + req.params.id);
        const newPath = path.join(__dirname, '../storage/shared/addon/' + newName);
        fs.renameSync(oldPath, newPath);
    }

    res.status(201);
}