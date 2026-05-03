import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import {defineConfig, loadEnv} from 'vite';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig(({mode}) => {
  const env = loadEnv(mode, '.', '');
  return {
    plugins: [
      react(), 
      tailwindcss(),
      VitePWA({
        registerType: 'autoUpdate',
        workbox: {
          maximumFileSizeToCacheInBytes: 5 * 1024 * 1024, // 5MB
        },
        manifest: {
          name: 'Vibesight',
          short_name: 'Vibesight',
          start_url: '/',
          display: 'standalone',
          background_color: '#0E2A1F',
          theme_color: '#2E7D52',
          icons: [
            { src: '/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any maskable' },
            { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
            { src: '/icon.svg', sizes: 'any', type: 'image/svg+xml' },
          ],
          share_target: {
            action: '/share-target',
            method: 'GET',
            params: {
              title: 'title',
              text: 'text',
              url: 'url'
            }
          }
        }
      })
    ],
    define: {
      'process.env.GEMINI_API_KEY': JSON.stringify(env.GEMINI_API_KEY),
    },
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '.'),
      },
    },
    server: {
      // HMR is disabled in AI Studio via DISABLE_HMR env var.
      hmr: process.env.DISABLE_HMR !== 'true',
    },
    build: {
      chunkSizeWarningLimit: 1500,
      rollupOptions: {
        output: {
          manualChunks(id: string) {
            if (id.includes('node_modules')) {
              if (id.includes('tesseract')) return 'vendor-tesseract';
              if (id.includes('recharts') || id.includes('/d3-')) return 'vendor-charts';
              if (id.includes('@mediapipe') || id.includes('@tensorflow')) return 'vendor-vision';
              if (id.includes('@google/genai')) return 'vendor-genai';
              if (id.includes('framer-motion')) return 'vendor-framer';
            }
          },
        },
      },
    },
  };
});
