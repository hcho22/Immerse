import { defineConfig } from "vitest/config";

// The end-to-end run on Convex's own local backend (local-backend/). It downloads the pinned backend binary once
// into the user's cache, so it is a separate command: `npm run test:local-backend`.
export default defineConfig({
  test: {
    environment: "node",
    globalSetup: ["tests/support/global-setup.ts"],
    include: ["local-backend/**/*.test.ts"],
    testTimeout: 120_000,
    hookTimeout: 300_000,
    fileParallelism: false,
    sequence: { concurrent: false },
  },
});
