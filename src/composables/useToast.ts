import { computed, reactive } from 'vue'

export type ToastKind = 'success' | 'error' | 'info'

type ToastMessage = {
  id: number
  kind: ToastKind
  message: string
}

const state = reactive({
  items: [] as ToastMessage[],
  nextId: 1
})

function push(message: string, kind: ToastKind = 'info', durationMs = 2800) {
  const id = state.nextId++
  state.items.push({ id, kind, message })

  window.setTimeout(() => {
    const index = state.items.findIndex((item) => item.id === id)
    if (index >= 0) {
      state.items.splice(index, 1)
    }
  }, durationMs)
}

function remove(id: number) {
  const index = state.items.findIndex((item) => item.id === id)
  if (index >= 0) {
    state.items.splice(index, 1)
  }
}

export function useToast() {
  return {
    toasts: computed(() => state.items),
    success: (message: string) => push(message, 'success'),
    error: (message: string) => push(message, 'error', 4000),
    info: (message: string) => push(message, 'info'),
    remove
  }
}
