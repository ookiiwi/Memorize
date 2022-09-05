const mongoose = require('mongoose');

const sessionSchema = mongoose.Schema({
    name: { type: String, required: true },
    status: { type: String, required: true },
    users: { type: Map, required: true }
});

module.exports = mongoose.model('Session', sessionSchema);