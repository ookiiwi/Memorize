const fs = require('fs');
const path = require('path');
const Group = require('../models/group');
const File = require('../models/file');

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
        }
        , { name: 1 }, (err, file) => {
            if (err) {
                console.log('err');
            } else {
                console.log('file', file)
            }
        }).clone();

    return files;
};

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

    // owner
    if (file.owner == userId) {
        perm >>= 2;
        ret |= perm & 3;
    }

    return ret;
}

exports.resolveUserstorage = (path, id) => {
    const ust = 'userstorage';
    const gst = 'globalstorage';
    let ret = path;

    if (path.startsWith('/' + ust)) {
        if (!id) throw "Forbidden access";
        ret = ret.replace(ust, 'user/' + id);
    }
    else if (path.startsWith('/' + gst)) {
        ret = ret.replace(gst, 'global');
    }

    return ret;
}