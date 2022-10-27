const path = require('path');
const shell = require('shelljs');

exports.find = (req, res) => {
    goToDictDir();

    const lang = req.query.lang;
    const key = req.query.key;
    const keyIds = venvExec('slob find ' + lang + '/' + lang + '.slob ' + key);

    shell.exec('which python');

    if (keyIds.code !== 0) {
        res.status(500).send("Slob find error");
        return;
    }

    const ret = keyIds.trim().split('\n').reduce((map, obj) => {
        const tmp = obj.split(' ');
        map[tmp[0]] = tmp[2];
        return map;
    }, {});

    res.status(201).json(ret);
};

exports.get = (req, res) => {
    goToDictDir();

    const lang = req.query.lang;
    const id = req.params.id;
    const ret = venvExec('slob get ' + lang + '/' + lang + '.slob ' + id);

    if (ret.code !== 0) {
        throw "Slob get error";
    }

    res.set('Content-Type', 'application/xml');
    res.status(201).send(ret.toString());
};

function goToDictDir() {
    const p = path.join(__dirname, '../dict/resources');

    if (shell.cd(p).code !== 0) {
        throw "Shell error";
    }
}

function venvExec(cmd) {
    const ret = shell.exec('. ../tools/venv/bin/activate && ' + cmd);

    if (ret.code !== 0) {
        throw "Shell error";
    }

    return ret;
}