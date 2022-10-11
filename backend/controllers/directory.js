const File = require('../models/file');
const fs = require('fs');
const shell = require('shelljs');
const { testPermissions, resolveUserstorage } = require('../utils/file-utils');

exports.mkdir = (req, res) => {
    const file = File({
        owner: req.auth.userId,
        group: req.body.group,
        name: req.body.path,
        permissions: parseInt(req.body.permissions, 4)
    });

    // resolve /userstorage to /storage/user/<userId>
    const p = resolveUserstorage(req.body.path, req.auth.userId);
    fs.mkdirSync(p);

    console.log('mkdir: ' + p + ' from ' + req.body.path);

    if (req.body.git_init) {
        if (shell.exec("git init " + p).code !== 0){
            throw "Git error";
        }
    }

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
    // Check owner to avoid matching first identical name
    File.findOne({ name: req.query.path, owner: req.auth.userId }).then(
        async (file) => {
            if (!file) {
                throw "File not found. " + req.query.path;
            }

            const perm = await testPermissions(file, req.auth.userId);

            if (!(perm & 2)) {
                throw "Forbidden access";
            }

            const p = resolveUserstorage(req.query.path, req.auth.userId);
            const dirContent = fs.readdirSync(p).filter((filename) => !filename.startsWith('.'));
            let ret = new Object();

            for await (const e of dirContent) {
                const isfile = fs.lstatSync(p + '/' + e).isFile();
                if (isfile) {
                    const f = await File.findById(e);
                    
                    if (f) {
                        const fPerm = await testPermissions(f, req.auth.userId);
                        if (fPerm & 2) ret[f.name] = e;
                    }
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
    res.status(500).send('Not implemented');
};

exports.delete = (req, res) => {
    File.findOneAndDelete({ name: req.body.path }).then(
        (file) => {
            if (!file) {
                throw "File not found. Cannot delete '" + req.body.path + "'";
            }

            const p = resolveUserstorage(req.body.path, req.auth.userId);
            //TODO: delete files from db

            fs.rmSync(p, { recursive: true, force: true });

            res.status(201).send();
        }).catch(
            (err) => {
                res.status(500).json({ err });
            }
        )
};