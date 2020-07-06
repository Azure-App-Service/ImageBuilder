const express = require('express')
const app = express()
var port = process.env.PORT
if (port == null) {
    port =  8080;
}

app.get('/', (req, res) => res.send('Hello World!'))

app.listen(port, () => console.log(`Example app listening at http://localhost:${port}`))
