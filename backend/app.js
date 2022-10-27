const express = require('express');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');
const userRoutes = require('./routes/user');
const fileRoutes = require('./routes/file');
const dirRoutes = require('./routes/directory');
const dictRoutes = require('./routes/dict');
const auth = require('./middleware/auth');
const app = express();
const cors = require('cors');
const port = 3000;

mongoose.connect('mongodb+srv://admin:bX3GHQlOtCHaSPOP@memodb.fsc75sv.mongodb.net/?retryWrites=true&w=majority', 
    { useNewUrlParser: true,
      useUnifiedTopology: true })
    .then(() => console.log('MongoDB connection succeeded !'))
    .catch(() => console.log('MongoDB connection failed !'));

mongoose.connection.on('disconnected', err => {
  console.error(err);
  console.log('Mongoose error');
});

app.use(cors());

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

app.get('/isLoggedIn', auth, (req, res) => { res.send('check if logged'); });
app.use('/auth', userRoutes);
app.use('/file', fileRoutes);
app.use('/dir', dirRoutes);
app.use('/dict', dictRoutes);

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
});

app.on('uncaughtException', (err) => {
  console.error(err);
  console.log("Node not exiting");
});