import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Node, not the edge runtime: the push sender runs in Convex's Node runtime, and the upload tests reach a real
    // S3-compatible emulator over the network.
    environment: "node",
    globalSetup: ["tests/support/global-setup.ts"],
    setupFiles: ["tests/support/env.ts"],
    include: ["tests/**/*.test.ts"],
    testTimeout: 30_000,
    hookTimeout: 60_000,
    server: { deps: { inline: ["convex-test"] } },
  },
});
