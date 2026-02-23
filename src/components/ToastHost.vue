<script setup lang="ts">
import { useToast } from '@/composables/useToast'

const toast = useToast()

const toneClass: Record<'success' | 'error' | 'info', string> = {
  success: 'toast-success',
  error: 'toast-error',
  info: 'toast-info'
}
</script>

<template>
  <div class="toast-host" aria-live="polite" aria-atomic="true">
    <div
      v-for="item in toast.toasts.value"
      :key="item.id"
      class="toast-item"
      :class="toneClass[item.kind]"
      role="status"
    >
      <p>{{ item.message }}</p>
      <button type="button" class="toast-close" @click="toast.remove(item.id)" aria-label="Dismiss notification">
        ×
      </button>
    </div>
  </div>
</template>
