const express = require('express');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');
const userRoutes = require('./routes/user');
const auth = require('./middleware/auth');
const app = express();
const port = 3000;

mongoose.connect('mongodb+srv://admin:bX3GHQlOtCHaSPOP@memodb.fsc75sv.mongodb.net/?retryWrites=true&w=majority', 
    { useNewUrlParser: true,
        useUnifiedTopology: true })
    .then(() => console.log('MongoDB connection succeeded !'))
    .catch(() => console.log('MongoDB connection failed !'));


app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content, Accept, Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
  next();
});

app.use(bodyParser.json());
app.use('/auth', userRoutes);
app.get('/isLoggedIn', auth, (req, res) => {
  res.send('check if logged');
});
app.get('/test_get', auth, (req, res) => {
  res.send('test get booboom');
});

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
});