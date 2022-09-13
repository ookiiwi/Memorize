const fs = require('fs');

exports.splitPath = (path) => {
    const ret = [...new Set(path.split('/'))];
    ret[0] = '/';
    return ret;
}