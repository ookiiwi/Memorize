const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const User = require('../models/user');

exports.signup = (req, res, next) => {
    bcrypt.hash(req.body.password, 10).then(hash => {
        const user = new User({
            email: req.body.email,
            username: req.body.username,
            password: hash
        });

        user.save()
            .then(() => res.status(201).json({ message: 'User created !' }))
            .catch(err => res.status(400).json({ err }));
    })
    .catch(err => res.status(500).json({ err : "encryption error" }));
};

exports.login = (req, res, next) => {
    User.findOne(req.body.email ? { email: req.body.email } : { username: req.body.username })
        .then(user => {
            if (!user) {
                return res.status(401).json({ message: 'Invalid credentials usr' });
            }

            bcrypt.compare(req.body.password, user.password)
                .then(valid => {
                    if (!valid) {
                        return res.status(401).json({ message: 'Invalid credentials' });
                    }

                    res.status(200).json({
                        userId: user._id,
                        token: jwt.sign(
                            { userId: user._id },
                            'RANDOM_TOKEN_SECRET',
                            { expiresIn: '60m' }
                        )
                    });

                })
                .catch(err => res.status(500).json({ err }));
        })
        .catch(err => res.status(500).json({ err }));
};