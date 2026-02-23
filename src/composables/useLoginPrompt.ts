import { computed, reactive } from 'vue'

const state = reactive({
  open: false,
  message: 'Please sign in with Google to continue.'
})

export function useLoginPrompt() {
  function openLoginPrompt(message?: string) {
    state.message = message || 'Please sign in with Google to continue.'
    state.open = true
  }

  function closeLoginPrompt() {
    state.open = false
  }

  return {
    open: computed(() => state.open),
    message: computed(() => state.message),
    openLoginPrompt,
    closeLoginPrompt
  }
}
