const File = require('../models/file');
const path = require('path');
const fs = require('fs');
const { testPermissions, resolveUserstorage } =  require('../utils/file-utils');

exports.mkdir = (req, res) => {
    const file = File({
        owner: req.auth.userId,
        group: req.body.group,
        name: req.body.path,
        permissions: parseInt(req.body.permissions, 4)
    });

    // resolve /userstorage to /storage/user/<userId>
    const p = path.join(__dirname, '../storage' + resolveUserstorage(req.body.path, req.auth.userId));
    fs.mkdirSync(p);

    console.log('mkdir: ' + p + ' from ' + req.body.path);

    file.save().then(
        () => {
            if (!req.skipResponse) res.status(201).json({ id: file._id });
        }
    ).catch(
        (err) => {
            console.log('Error when creating dir: ' + err);
            if (!req.skipResponse) {
                res.status(500).json({ err });
            } else {
                throw err;
            }
        }
    )
};

exports.ls = (req, res) => {
    // resolve /userstorage to /storage/user/<userId>s
    File.findOne({ name: req.query.path }).then(
        async (file) => {
            if (!file) {
                throw "File not found. " + req.query.path;
            }
            
            req.query.path = resolveUserstorage(req.query.path, req.auth.userId);
            const perm = await testPermissions(file, req.auth.userId);
            
            if (!(perm & 2)) {
                console.log('perm: ' + perm);
                throw "Forbidden access";
            }

            const p = path.join(__dirname, '../storage' + req.query.path);
            console.log('ret: ' + p);
            const dirContent = fs.readdirSync(p);
            let ret = new Object();

            for await (const e of dirContent) {
                const isfile = fs.lstatSync(p + '/' + e).isFile();
                if (isfile) {
                    const f = await File.findById(e);
                    ret[f.name] = e;
                } else {
                    ret[e] = null;
                }
            }

            res.status(201).json(ret);
        }
    ).catch(
        (err) => {
            console.log('error during ls: ' + err);
            res.status(404).json({ err });
        }
    )
};

exports.update = (req, res) => {

};

exports.delete = (req, res) => {
    File.findOneAndDelete({ name: req.body.path }).then(
        (file) => {
            if (!file) {
                throw "File not found. Cannot delete '" + req.body.path + "'"; 
            } 

            const p = path.join(__dirname, '../storage' + resolveUserstorage(req.body.path, req.auth.userId));
            fs.rmSync(p, { recursive: true, force: true });

            res.status(201);
        }).catch(
            (err) => {
                res.status(500).json({ err });
            }
        )
};