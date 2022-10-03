const fs = require('fs');
const path = require('path');
const Group = require('../models/group');


exports.search = (value, dir) => {

    if (value == null) {
        throw "prout";
    }

    const dirPath = path.join(__dirname, '../storage' + dir);
    let files = fs.readdirSync(dirPath);

    if (value.length) {
        console.log('search '+ value + ' in ' + files);
        files = files.filter(file => file.startsWith(value));
    }

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
    if (!path.startsWith('/userstorage')) return path;
    if (!id) throw "Forbidden access";
    return path.replace('userstorage', 'user/'+id);
}