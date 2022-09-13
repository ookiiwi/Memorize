const mongoose = require('mongoose');

const listSchema = mongoose.Schema({
    owner: { type: String, required: true },
    name: { type: String, required: true },
    status: { type: String, required: true },
    users: { type: Object, default: new Object() } // {userID: permissions}
});

module.exports = mongoose.model('List', listSchema);