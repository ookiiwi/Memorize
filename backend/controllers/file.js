const ramda = require('ramda');
const path = require('path');
const fs = require('fs');

const User = require('../models/user');
const { splitPath } = require('../utils/path-utils');
const List = require('../models/list');

exports.delete = (req, res, next) => {
    User.findById(req.auth.userId)
    .then(
        (user) => {
        const path = splitPath(req.body.path);
        
        if (!ramda.hasPath(path, user.listPathStructure)){
            throw 'Cannot delete directory ' + req.body.path + '. Directory does not exists';
        }
        
        const dir = ramda.path(path, user.listPathStructure)

        if (!dir) {
            rmList(path[path.length-1]);
        } else {
            rm(dir);
        }

        user.listPathStructure = ramda.dissocPath(path, user.listPathStructure);
        user.save();
        
    }).catch((err) => { 
        console.log(err);
        res.status(400).json({ err })
    });
}

function rm(dir) {
    const dirs = [];

    if (!dir) {
        return;
    }

    Object.entries(dir).forEach((key, index) => {
        if (dir[key] instanceof Object) {
            dirs.push(dir[key]);
        } else {
            rmList(key);
        }
    });

    if (!dirs.length) return;

    dirs.forEach((value) => {
        rm(value);
    });
}

function rmList(id){
    List.findById(id).then((list) => {

        const p = path.join(__dirname, '../lists/' + list.status + '/' + list._id);
        fs.unlinkSync(p);
    });
}