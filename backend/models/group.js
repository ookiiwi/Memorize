const mongoose = require('mongoose');

const groupSchema = mongoose.Schema({
    name: { type: String, required: true },
    users: { type: Map, required: true }
});

module.exports = mongoose.model('Session', groupSchema);