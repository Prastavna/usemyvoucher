<script setup lang="ts">
import { onMounted } from 'vue'
import AppNav from '@/components/AppNav.vue'
import ToastHost from '@/components/ToastHost.vue'
import { useAuth } from '@/composables/useAuth'

const auth = useAuth()

onMounted(async () => {
  await auth.initializeAuth()
})
</script>

<template>
  <UApp>
    <div class="app-shell">
      <AppNav v-if="auth.isAuthenticated.value" />
      <main class="app-main">
        <RouterView />
      </main>
      <ToastHost />
    </div>
  </UApp>
</template>
