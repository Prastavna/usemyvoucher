<script setup lang="ts">
import { useToast } from '@/composables/useToast'

const toast = useToast()

const toneClass: Record<'success' | 'error' | 'info', string> = {
  success: 'border-emerald-300 bg-emerald-50',
  error: 'border-rose-300 bg-rose-50',
  info: 'border-sky-300 bg-sky-50'
}
</script>

<template>
  <div class="fixed bottom-4 right-4 z-50 grid gap-2" aria-live="polite" aria-atomic="true">
    <div
      v-for="item in toast.toasts.value"
      :key="item.id"
      class="flex min-w-[260px] items-center justify-between gap-3 rounded-md border px-3 py-2 text-sm text-stone-800 shadow"
      :class="toneClass[item.kind]"
      role="status"
    >
      <p>{{ item.message }}</p>
      <button
        type="button"
        class="inline-flex size-6 items-center justify-center rounded text-lg leading-none text-stone-600 hover:bg-stone-200"
        @click="toast.remove(item.id)"
        aria-label="Dismiss notification"
      >
        ×
      </button>
    </div>
  </div>
</template>
