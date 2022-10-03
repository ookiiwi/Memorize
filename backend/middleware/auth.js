const jwt = require('jsonwebtoken');
const User = require('../models/user');

module.exports = (req, res, next) => {
    try {
        const token = req.headers.authorization.split(' ')[1];
        const decodedToken = jwt.verify(token, 'RANDOM_TOKEN_SECRET');
        const userId = decodedToken.userId;

        req.auth = {
            userId: userId
        };

        User.findById(userId).then((user) => {
            if (!user) {
                throw "Unknown user";
            }
            next();
        }).catch((err) => {
            res.status(401).json({ err });
        })


    } catch (err) {
        if (req.params.authNoExcept) { 
            req.auth = { err };
            next();
        } else {
            res.status(401).json({ err });
        }
    }
};