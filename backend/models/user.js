const mongoose = require('mongoose');
const uniqueValidator = require('mongoose-unique-validator');

const userSchema = mongoose.Schema({
    email: { type: String, required: true, unique: true },
    username: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    addons: { type: Array, default: new Array() }
});

userSchema.plugin(uniqueValidator);

module.exports = mongoose.model('User', userSchema);