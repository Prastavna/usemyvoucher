import { createApp } from 'vue'
import App from './App.vue'
import { createRouter, createWebHistory } from 'vue-router'
import ui from '@nuxt/ui/vue-plugin'
import './main.css'

const router = createRouter({
  routes: [],
  history: createWebHistory()
})

createApp(App).use(router).use(ui).mount('#app')
