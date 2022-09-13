const List = require('../models/list');
const User = require('../models/user');
const ramda = require('ramda');

const { splitPath } = require('../utils/path-utils');

exports.mkdir = (req, res, next) => {
    User.findById(req.auth.userId)
    .then(
        (user) => {
            const path = splitPath(req.body.path);

            if (ramda.path(path, user.listPathStructure) != null){
                throw 'Cannot create directory ' + path + '. Directory exists';
            }

            user.listPathStructure = ramda.assocPath(path, {}, user.listPathStructure);
            user.save();
            
    }).catch((error) => { 
        console.log(error);
        res.status(400).json({ error })
    });
};

exports.ls = (req, res, next) => {
    User.findById(req.auth.userId)
        .then(
            (user) => {
                let opCnt = 0;

                function sendResponse() {
                    if (!content || ++opCnt >= Object.keys(content).length) {
                        res.status(201).json(content);
                    }
                }
                const content = ramda.path(splitPath(req.body.path), user.listPathStructure);
                
                if (content && Object.keys(content).length){
                    Object.keys(content).forEach( function (key, index) {
                        List.findById(key)
                            .then((list) => {
                                content[key] = list.name;
                                sendResponse();
                            }).catch((err) => {
                                sendResponse();
                            });

                    });
                } else {
                    console.log('not content');
                    sendResponse();
                }

            }
        ).catch((error) => { 
            console.log(error);
            res.status(400).json({ error })
         });
}

exports.update = (req, res, next) => {}