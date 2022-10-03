const mongoose = require('mongoose');

const groupSchema = mongoose.Schema({
    name: { type: String, required: true },
    users: { type: Array, required: true }
});

module.exports = mongoose.model('Group', groupSchema);