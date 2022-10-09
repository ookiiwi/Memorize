const path = require('path');
const fs = require('fs');
const shell = require('shelljs');

const File = require('../models/file');
const upload = require('../middleware/multer-config');
const Group = require('../models/group');
const { assert } = require('console');
const { testPermissions, resolveUserstorage } = require('../utils/file-utils');

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
    const id = req.params.id;

    File.findById(id).then(
        async (file) => {
            if (!file) {
                throw "File not found.";
            }

            // TODO: check dir permissions

            const perm = await testPermissions(file, req.auth.userId);

            if (!(perm & 1)) {
                throw "Forbidden access";
            }

            upload(req, res, () => {
                file.name = req.file.originalname;
                file.group = req.body.group || file.group;
                file.permissions = req.body.permissions ? parseInt(req.body.permissions, 4) : file.permissions;


                if (req.body.version) {
                    console.log('commit:', req.body.version);

                    if (shell.cd(req.file.destination).code !== 0) {
                        throw "Shell error during cd to " + req.file.destination;
                    }

                    const tag = 'v' + id + '_' + req.body.version;
                    const addCmd = 'git add "' + req.file.path + '"';
                    const commitCmd = 'git commit -m "' + Date.UTC() + '"';
                    const tagCmd = 'git tag ' + tag;

                    if (shell.exec(addCmd + ' && ' + commitCmd + ' && ' + tagCmd).code !== 0) {
                        throw "Git error";
                    }
                }

                file.save().then(() => {
                    res.status(201).send();
                }).catch(
                    (err) => {
                        res.status(500).json({ err });
                    }
                );
            });
        }
    ).catch(
        (err) => {
            res.status(401).json({ err });
        }
    );

};

exports.read = (req, res) => {
    const id = req.query.path.split('/').pop();

    File.findById(id).then(
        async (file) => {
            if (!file) {
                throw "File not found.";
            }

            const perm = await testPermissions(file, req.auth.userId);

            if (!(perm & 2)) {
                throw "Forbidden access";
            }
            assert(req.query.path);

            req.query.path = resolveUserstorage(req.query.path, req.auth.userId);
            const p = path.join(__dirname, '../storage' + req.query.path);

            const fileDir = p.replace(/(\/[^\/]*)$/, '');

            if (shell.cd(fileDir).code !== 0) {

                throw "Shell error with cd";

            }

            const version = req.query.version;
            const tagsCmd = shell.exec('git tag -l v' + id + '_*');

            if (tagsCmd.code !== 0) {
                throw "Git error";
            }

            const tags = tagsCmd.trim().split('\n').map((e) => {
                return e.split('_')[1];
            });

            const ret = version ? readVersion(id, 'v' + id + '_' + version) : fs.readFileSync(p).toString();
            res.status(201).json({ ret, versions: tags });
        }
    ).catch(
        (err) => {
            console.log('error read', err);
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
            const fileDir = p.replace(/(\/[^\/]*)$/, '');

            if (shell.cd(fileDir).code !== 0) {
                throw "Git error";
            }

            // get all tags for this file
            const tagsCmd = shell.exec('git tag -l v' + id + '_*');
            if (tagsCmd.code !== 0) {
                throw "Git error";
            }
            const tags = tagsCmd.trim().split('\n');

            let hashDrop = '';
            console.log('tags:', tags);
            
            // get commits hash for each tags
            for (let e of tags){
                let commitCmd = shell.exec('git show ' + e + ' --format="%h" -s');
                if (commitCmd.code !== 0) {
                    throw "Git error";
                }

                let hash = commitCmd.trim();
                hashDrop+='s/^pick ' + hash + '/drop ' + hash + '/;';
            }

            console.log('hashArr:', hashDrop);

            // drop commits
            const dropCmd = 'GIT_SEQUENCE_EDITOR="sed -i -re \'' + hashDrop + '\'" git rebase -i --autostash --root';
            
            fs.rmSync(p, { recursive: false, force: true });

            if (shell.exec(dropCmd).code !== 0) {
                throw "Git error";
            }


            res.status(201).send();
        }
    ).catch(
        (err) => {
            console.log('Deletion error: ' + err);
            res.status(500).json({ err });
        }
    );


}

function readVersion(id, version) {
    const commitCmd = shell.exec('git show ' + version + ' --format="%h" -s');

    if (commitCmd.code !== 0) {
        throw 'Git error';
    }

    const commit = commitCmd.trim().replace('\n', '');

    const filenameCmd = shell.exec("git ls-tree --name-only -r " + commit);

    if (filenameCmd.code !== 0) {
        throw "Git error" + filename;
    }

    const filename = filenameCmd.match(new RegExp(".*" + id));
    const ret = shell.exec("git show " + commit + ':"' + filename + '"');

    if (ret.code !== 0) {
        console.log('cmd ret: ', ret);
        throw "Git error";
    }

    return ret;
}