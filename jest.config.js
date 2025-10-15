module.exports = {
  testEnvironment: "node",
  coverageDirectory: "coverage",
  collectCoverageFrom: [
    "src/**/*.js",
    "!src/server.js",
    "!src/**/__tests__/**",
  ],
  testMatch: ["**/__tests__/**/*.test.js"],
  verbose: true,
};
