const http = require("http");

http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end("<h1>Green Version - v1</h1>");
}).listen(3000);