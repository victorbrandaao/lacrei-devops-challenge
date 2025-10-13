const express = require("express");
const statusRouter = require("./routes/status");

const app = express();

// Middleware para JSON
app.use(express.json());

// Registrar rotas
app.use("/", statusRouter);

// Exportar app sem iniciar servidor (para testes)
module.exports = app;
