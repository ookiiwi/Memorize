const mongoose = require('mongoose');

const listSchema = mongoose.Schema({
    status: { type: String, required: true },
    users: { type: Map, required: true }
});

module.exports = mongoose.model('List', listSchema);