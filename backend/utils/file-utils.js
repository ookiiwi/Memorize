const fs = require('fs');
const path = require('path');

exports.search = (req, res, next) => {
    const search = req.query.search;

    if (search == null) {
        throw "prout";
    }

    console.log('search');

    const dirPath = path.join(__dirname, '../storage' + req.params.dir);
    let files = fs.readdirSync(dirPath);

    if (search.length) {
        console.log('search '+ search + ' in ' + files);
        files = files.filter(file => file.startsWith(search));
    }

    res.status(201).json(files);
};