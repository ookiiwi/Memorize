const mongoose = require('mongoose');

const fileSchema = mongoose.Schema({
    owner: { type: String, required: true },
    group: { type: String, default: null },
    name:  { type: String, required: true },
    permissions: { type: Number, required: true } // rw----
});

module.exports = mongoose.model('File', fileSchema);