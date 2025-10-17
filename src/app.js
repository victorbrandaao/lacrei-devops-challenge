const express = require("express");
const statusRouter = require("./routes/status");

const app = express();

// Middleware para JSON
app.use(express.json());

// Registrar rotas
app.use("/", statusRouter);

// Middleware para rotas não encontradas (404)
app.use((req, res) => {
  res.status(404).json({ error: "Rota não encontrada" });
});

// Exportar app sem iniciar servidor (para testes)
module.exports = app;
