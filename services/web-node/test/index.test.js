const { test } = require("node:test");
const assert = require("node:assert/strict");
const { version } = require("../package.json");
const app = require("../src/index.js");

test("GET /version returns the package version", async () => {
  const server = app.listen(0);
  const { port } = server.address();

  try {
    const response = await fetch(`http://localhost:${port}/version`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { version });
  } finally {
    server.close();
  }
});
