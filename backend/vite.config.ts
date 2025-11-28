import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import ui from "@nuxt/ui/vite";

export default defineConfig({
  plugins: [
    vue({
      template: {
        transformAssetUrls: {
          base: null,
          includeAbsolute: false,
        },
      },
    }),
    ui({
      inertia: true,
    })
  ],
  build: {
    manifest: true,
    rollupOptions: {
      input: "src/main.ts",
    },
  },
  server: {
    port: 5174,
    hmr: {
      host: "localhost",
    },
  },
});
