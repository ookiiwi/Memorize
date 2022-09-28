const mongoose = require('mongoose');
const uniqueValidator = require('mongoose-unique-validator');

const userSchema = mongoose.Schema({
    email: { type: String, required: true, unique: true },
    username: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    listPathStructure: { type: Object, default: new Object()},
    addon_schema: { type: Object, default: new Object },
});

userSchema.plugin(uniqueValidator);

module.exports = mongoose.model('User', userSchema);