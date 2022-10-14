const fs = require('fs');

const File = require('../models/file');
const Group = require('../models/group');
const { assert } = require('console');
const { testPermissions, resolveUserstorage, search } = require('../utils/file-utils');

exports.update = async (req, res) => {
    try {
        const uploadedFile = JSON.parse(req.file.buffer.toString());
        const version = uploadedFile.file.version || 'HEAD';
        const path = req.body.path + '/' + uploadedFile.meta.id;
        const file = fs.existsSync(path) ? JSON.parse(fs.readFileSync(path).toString()) : {};

        if (!Object.keys(file).length) {
            if (!req.auth) {
                throw "Forbiden access.";
            }
        }

        const dbFile = File({
            _id: uploadedFile.meta.id,
            owner: req.auth.userId,
            name: uploadedFile.meta.name,
            group: uploadedFile.meta.group,
            permissions: uploadedFile.meta.permissions,
        });

        File.findOneAndUpdate({
            $and: [
                { _id: dbFile._id },
                {
                    $or: [
                        {
                            permissions: { $bitsAllSet: 2 }
                        },
                        {
                            $and: [
                                { permissions: { $bitsAllSet: 8 } },
                                { group: { $in: [] } }
                            ]
                        },
                        {
                            $and: [
                                { permissions: { $bitsAllSet: 32 } },
                                { owner: { $eq: req.auth.userId } }
                            ]
                        }
                    ]
                }
            ]
        }, dbFile, { upsert: true }).then((_) => {
            file.meta = uploadedFile.meta;
            file[version] = uploadedFile.file;

            fs.writeFileSync(path, JSON.stringify(file));
            res.status(201).send();
        }).catch((err) => res.status(500).json({ err }));
    }
    catch (e) {
        console.log('err:', e);
    }
};

exports.read = async (req, res) => {
    const path = resolveUserstorage(req.query.path, req.auth.userId);

    assert(fs.existsSync(path));

    const version = req.query.version || 'HEAD';
    const file = JSON.parse(fs.readFileSync(path));

    File.findById(file.meta.id).then(async (dbFile) => {
        const perm = await testPermissions(dbFile, req.auth.userId);

        if (!(perm & 2)) {
            throw "Forbidden access";
        }

        const versions = Object.keys(file);
        versions.splice(versions.indexOf('meta'), 1);
        versions.splice(versions.indexOf('HEAD'), 1);
        file.meta.versions = versions;

        res.status(201).send(JSON.stringify({
            meta: file.meta,
            file: file[version]
        }));
    }).catch((err) => res.status(500).json({ err }));
};

exports.delete = async (req, res) => {
    if (!fs.existsSync) {
        throw "File not found.";
    }

    const path = resolveUserstorage(req.body.path, req.auth.userId);
    const version = req.body.version;
    const file = JSON.parse(fs.readFileSync(path));

    if (version) {
        delete file.meta.versions[version];
        delete file[version];

        fs.writeFileSync(path, JSON.stringify(file));
    } else {
        await File.findByIdAndDelete(file.meta.id);
        fs.rmSync(path);
    }

    res.status(201).send();
}

exports.search = (req, res) => {
    search(req.query.value, '', req.auth ? req.auth.userId : null).then((files) => {
        res.status(201).json(files);
    }).catch((e) => {
        console.log('error:', e);
        res.status(500).json({ error: e });
    });
};