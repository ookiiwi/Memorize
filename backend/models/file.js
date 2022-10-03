const mongoose = require('mongoose');

const fileSchema = mongoose.Schema({
    owner: { type: String, required: true },
    group: { type: String, default: null },
    name:  { type: String, required: true },
    permissions: { type: Number, default: 63 } // rw----
});

module.exports = mongoose.model('File', fileSchema);