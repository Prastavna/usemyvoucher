<script setup lang="ts">
import { onMounted } from 'vue'
import AppNav from '@/components/AppNav.vue'
import LoginPromptModal from '@/components/LoginPromptModal.vue'
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
      <AppNav />
      <main class="app-main">
        <RouterView />
      </main>
      <LoginPromptModal />
      <ToastHost />
    </div>
  </UApp>
</template>
