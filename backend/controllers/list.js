const List = require('../models/list');
const User = require('../models/user');
const fs = require('fs');
const ramda = require('ramda');
const path = require('path');

const { splitPath } = require('../utils/path-utils');

exports.get = (req, res, next) => {
    List.findById(req.params.id)
    .then((list) => {
        const permissions = list.users[req.auth.userId];

        if (list.owner != req.auth.userId && 
            list.status != 'public' && !permissions){
            res.status(403).json({ error: "Access denied" });
            return;
        }

        const p = path.join(__dirname, '../lists/' + list.status + '/' + req.params.id);
        const file = fs.readFileSync(p).toString();

        res.status(200).json(file);

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
            list.name = req.file.originalname;
            list.status = req.body.status;

            list.save();
        })
        .catch(
            (error) => { 
                console.log(error);
                res.status(400).json({ error }) }
        );
}