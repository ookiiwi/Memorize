const path = require('path');
const fs = require('fs');

const File = require('../models/file');
const upload = require('../middleware/multer-config');
const Group = require('../models/group');
const { assert } = require('console');
const { testPermissions, resolveUserstorage } =  require('../utils/file-utils');

exports.create = (req, res) => {
    const file = File({
        _id: req.params.id,
        owner: req.auth.userId,
        group: req.body.group,
        name: req.file.originalname,
        permissions: parseInt(req.body.permissions, 4)
    });

    file.save().then(
        () => {
            res.status(201).json({ id: file._id });
        }
    ).catch(
        (err) => {
            console.log('Error when creating list: ' + err);
            res.status(500).json({ err });
        }
    )
};

exports.update = (req, res) => {
    File.findById(req.params.id).then(
        async (file) => {
            const perm = await testPermissions(file, req.auth.userId);

            if (!(perm & 1)) {
                throw "Forbidden access";
            }

            upload(req, res, () => {
                file.name = req.file.originalname,
                file.group = req.body.group || file.group;
                file.permissions = req.body.permissions ? parseInt(req.body.permissions, 4) : file.permissions;

                file.save();
                res.status(201);
            });
        }
    ).catch(
        (err) => {
            res.status(401).json({ err });
        }
    );

};

exports.read = (req, res) => {
    File.findById(req.params.id).then(
        async (file) => {
            const perm = await testPermissions(file, req.auth.userId);

            if (!(perm & 2)) {
                throw "Forbidden access";
            }
            assert(req.query.path);
            
            req.query.path = resolveUserstorage(req.query.path, req.auth.userId);
            const p = path.join(__dirname, '../storage' + req.query.path + '/' + req.params.id);
            console.log('ret: ' + p);
            const ret = fs.readFileSync(p).toString();

            res.status(201).json(ret);
        }
    ).catch(
        (err) => {
            res.status(500).json({ err });
        }
    )
};

exports.delete = (req, res) => {
    const id = req.body.path.split('/').pop();
    File.findByIdAndDelete(id).then(
        (file) => {
            if (file.owner != req.auth.userId) {
                throw "Cannot delete file unless you are the owner";
            }

            const p = path.join(__dirname, '../storage' + resolveUserstorage(req.body.path, req.auth.userId));
            fs.rmSync(p, { recursive: true, force: true });

            res.status(201);
        }
    ).catch(
        (err) => {
            console.log('Deletion error: ' + err);
            res.status(401).json({ err });
        }
    );


}