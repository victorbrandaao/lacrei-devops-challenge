const express = require("express");
const router = express.Router();

router.get("/status", (req, res) => {
  const response = {
    ok: true,
    env: process.env.NODE_ENV || "development",
    version: process.env.COMMIT_SHA || "local",
    timestamp: new Date().toISOString(),
  };

  res.status(200).json(response);
});

module.exports = router;
