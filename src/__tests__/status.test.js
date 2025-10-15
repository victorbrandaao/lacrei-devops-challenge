const request = require("supertest");
const app = require("../app");

describe("GET /status", () => {
  it("deve retornar 200 e JSON válido", async () => {
    const response = await request(app)
      .get("/status")
      .expect("Content-Type", /json/)
      .expect(200);

    expect(response.body).toHaveProperty("ok");
    expect(response.body).toHaveProperty("env");
    expect(response.body).toHaveProperty("version");
    expect(response.body).toHaveProperty("timestamp");
  });

  it("deve retornar ok: true", async () => {
    const response = await request(app).get("/status");

    expect(response.body.ok).toBe(true);
  });

  it("deve retornar env correto", async () => {
    process.env.NODE_ENV = "test";

    const response = await request(app).get("/status");

    expect(response.body.env).toBe("test");
  });

  it("deve retornar version do COMMIT_SHA", async () => {
    process.env.COMMIT_SHA = "abc123";

    const response = await request(app).get("/status");

    expect(response.body.version).toBe("abc123");
  });

  it("deve retornar timestamp em formato ISO", async () => {
    const response = await request(app).get("/status");

    // Validar que é uma data ISO válida
    expect(() => new Date(response.body.timestamp)).not.toThrow();
    expect(response.body.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });
});

describe("Rotas inexistentes", () => {
  it("deve retornar 404 para rotas não encontradas", async () => {
    const response = await request(app).get("/rota-inexistente");

    expect(response.status).toBe(404);
  });
});
