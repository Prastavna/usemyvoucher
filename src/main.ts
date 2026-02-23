import { createApp } from 'vue'
import App from './App.vue'
import ui from '@nuxt/ui/vue-plugin'
import './main.css'
import router from '@/router'

createApp(App).use(router).use(ui).mount('#app')
