/// <reference types="vitest/config" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  base: "/",
  // node_modules は Nix build（read-only store への symlink）のため、
  // 既定の node_modules/.vite にキャッシュを書けない。web/.vite へ逃がす
  cacheDir: ".vite",
  server: {
    host: "0.0.0.0",
    port: 5173,
    proxy: {
      "/api": "http://localhost:8000",
      "/health": "http://localhost:8000",
    },
  },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test-setup.ts"],
    /** vitestが拾うテストファイルを src 配下の .test.ts に限定する */
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov"],
      exclude: ["src/**/*.d.ts", "src/main.tsx"],
    },
  },
});
