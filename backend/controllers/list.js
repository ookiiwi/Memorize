const List = require('../models/list');
const User = require('../models/user');
const fs = require('fs');
const ramda = require('ramda');
const path = require('path');
const fu = require('../utils/file-utils');
const auth = require('../middleware/auth');

const { splitPath } = require('../utils/path-utils');

exports.get = (req, res, next) => {
    List.findById(req.params.id)
    .then((list) => {
        console.log('get list');
        function getList () {
            const permissions = req.auth ? list.users[req.auth.userId] : undefined;

            if (list.status !== 'shared' && !permissions && list.owner != req.auth.userId){
                res.status(403).json({ error: "Access denied" });
                return;
            }
    
            console.log('get ' + list.status + ' list');

            const p = path.join(__dirname, '../storage/' + list.status + '/list/' + req.params.id);
            const file = fs.readFileSync(p).toString();
    
            res.status(200).json(file);
        }

        if (list.status === 'private') auth(req, res, getList);
        else getList();
        

    }).catch((err) => { 
        console.log(err);
        res.status(404).json({ err })
    });
};

exports.upload = (req, res, next) => {
    const list = new List({
        _id: req.params.id,
        owner: req.auth.userId,
        name: req.file.originalname,
        status: req.body.status,
    });

    list.save().then(
        () => {
            res.status(201).json({
                listId: list._id
            })
            
            User.findById(req.auth.userId)
                .then(
                    (user) => {
                        // TODO: handle directory
                        // create list
                        user.listPathStructure = ramda.assocPath([...splitPath(req.body.path), list._id], null, user.listPathStructure);
                        user.save();
                    });
    }).catch(
        (error) => { 
            console.log(error);
            res.status(400).json({ error }) }
    );
};

exports.update = (req, res, next) => {
    // TODO: name changes == change name
    // TODO: status changes == move list
    // TODO: path changes == change path
    
    List.findById(req.params.id)
    .then((list) => {
        if (req.file) list.name = req.file.originalname;
        console.log('update to ' + req.body.status + ' status');
        
        if (list.status !== req.body.status) {
            // TODO: check if user allowed to
            const oldPath = path.join(__dirname, '../storage/' + list.status + '/list/' + list.id);
            list.status = req.body.status;
            const newPath = path.join(__dirname, '../storage/' + list.status + '/list/' + list.id);
            fs.renameSync(oldPath, newPath);
        }

            list.save();
        })
        .catch(
            (error) => { 
                console.log(error);
                res.status(400).json({ error }) }
        );
}

exports.search = (req, res, next) => {
    req.params.dir = '/shared/list';
    fu.search(req,res,next);
};