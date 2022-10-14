const File = require('../models/file');
const fs = require('fs');
const { testPermissions, resolveUserstorage } = require('../utils/file-utils');

exports.mkdir = (req, res) => {
    const p = resolveUserstorage(req.body.path, req.auth.userId);
    fs.mkdirSync(p);

    if (!req.skipResponse) res.status(201).send();
};

exports.ls = async (req, res) => {
    const path = resolveUserstorage(req.query.path, req.auth.userId);
    const content = fs.readdirSync(path).filter((filename) => !filename.startsWith('.'));
    let ret = new Array();

    for await (const e of content) {
        const isFile = fs.lstatSync(path + '/' + e).isFile();

        if (isFile) {
            const file = JSON.parse(fs.readFileSync(path + '/' + e));
            const dbFile = await File.findById(file.meta.id);

            const perm = await testPermissions(dbFile, req.auth.userId);
            if (perm & 2) ret.push(file.meta);
        } else {
            ret.push(e);
        }
    }

    res.status(201).json(ret);
};

exports.update = (req, res) => {
    res.status(500).send('Not implemented');
};

exports.delete = (req, res) => {
    const path = resolveUserstorage(req.body.path, req.auth.userId);

    if (!fs.existsSync(path)) {
        throw "File not found";
    }

    // TODO: rm children from db 
    fs.rmSync(path, { recursive: true, force: true });

    res.status(201).send();
};