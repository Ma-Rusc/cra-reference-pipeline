const express = require("express");
const { version } = require("../package.json");

const app = express();

app.get("/version", (req, res) => {
  res.json({ version });
});

if (require.main === module) {
  const port = process.env.PORT ?? 3000;
  app.listen(port, () => {
    console.log(`web-node listening on port ${port}`);
  });
}

module.exports = app;
