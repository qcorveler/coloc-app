import { createApp } from 'vue'
import { Dark, Dialog, Notify, Quasar } from 'quasar'
import langFr from 'quasar/lang/fr'
import '@quasar/extras/material-icons/material-icons.css'
import 'quasar/src/css/index.sass'
import './style.css'
import App from './App.vue'
import { router } from './router'

const app = createApp(App)

app.use(Quasar, {
  lang: langFr,
  plugins: { Notify, Dialog },
  config: {
    dark: 'auto',
  },
})

Dark.set('auto')
app.use(router).mount('#app')
