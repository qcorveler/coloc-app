import { join } from 'node:path'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { quasar, transformAssetUrls } from '@quasar/vite-plugin'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  envDir: '..',
  plugins: [
    vue({
      template: { transformAssetUrls },
    }),
    quasar({
      sassVariables: join(import.meta.dirname, 'src/quasar-variables.sass'),
      autoImportComponentCase: 'kebab',
    }),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'apple-touch-icon.png'],
      manifest: {
        name: 'Appli Coloc',
        short_name: 'Coloc',
        description: 'Organisation et vie de la coloc',
        theme_color: '#ffffff',
        background_color: '#ffffff',
        display: 'standalone', // Cache la barre d'adresse Chrome
        icons: [
          {
            src: 'https://via.placeholder.com/192.png', // URL temporaire valide pour débloquer Chrome
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: 'https://via.placeholder.com/512.png',
            sizes: '512x512',
            type: 'image/png'
          }
        ]
      }
    })
  ]
})
