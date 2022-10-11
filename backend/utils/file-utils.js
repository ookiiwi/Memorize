const fs = require('fs');
const path = require('path');
const Group = require('../models/group');
const File = require('../models/file');
const shell = require('shelljs');

exports.search = async (value, path, userId) => {
    if (value == null) {
        throw "prout";
    }

    const groups = [];
    const re = '^' + value + '[^\/]*$';
    console.log('value: "' + re + '"');

    const files = await File.find(
        {
            $and: [
                { name: { $regex: re } },
                {
                    $or: [
                        {
                            permissions: { $bitsAllSet: 2 }
                        },
                        {
                            $and: [
                                { permissions: { $bitsAllSet: 8 } },
                                { group: { $in: groups } }
                            ]
                        },
                        {
                            $and: [
                                { permissions: { $bitsAllSet: 32 } },
                                { owner: { $eq: userId } }
                            ]
                        }
                    ]
                }
            ]
        }, { name: 1 }, (err, file) => {
            if (err) {
                console.log('err');
            } else {
                console.log('file', file)
            }
        }).clone();

    return files.map((e) => {
        e.path = mapFileToPath(e._id, userId);
        return { _id: e._id, name: e.name, path: e.path };
    });
};

function mapFileToPath(fileId, userId) {
    function find(path) {
        const p = resolveUserstorage(path, userId);
        const ret = shell.exec('find ' + p + ' -name ' + fileId);

        if (ret.code !== 0) {
            throw 'Shell error';
        }

        return ret.trim().split('\n').map((e) => unresolveUserStorage(e, userId));
    }

    return (find('/globalstorage')[0] || find('/userstorage')[0]);
}

exports.testPermissions = async (file, userId) => {
    let perm = file.permissions;
    let ret = perm & 3;

    if (ret == 3 || !userId) return ret;
    perm >>= 2;
    
    const group = await Group.findById(file.group);
    if (group && group.users.has(userId)) {
        ret |= perm & 3;
    }
    
    if (ret == 3) return ret;
    perm >>= 2;
    
    if (file.owner == userId) {
        ret |= perm & 3;
    }

    return ret;
}

exports.resolveUserstorage = resolveUserstorage;

function resolveUserstorage(aPath, id) {
    const ust = '/userstorage';
    const gst = '/globalstorage';
    let ret = aPath;

    console.log('p:', aPath);

    if (aPath.startsWith(ust)) {
        if (!id) throw "Forbidden access";
        ret = ret.replace(ust, 'user/' + id);
    }
    else if (aPath.startsWith(gst)) {
        ret = ret.replace(gst, 'global');
    }

    return path.join(__dirname, '../storage/' + ret);
}

function unresolveUserStorage(path, id) {
    let ret = path.replace(/.*\/global/, '/globalstorage');
    if (id) ret = ret.replace(new RegExp('.*/user/' + id), '/userstorage');

    console.log('unresolve', path, 'to', ret);

    return ret;
}