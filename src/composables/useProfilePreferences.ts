import { computed, ref } from 'vue'

const STORAGE_KEY = 'usemyvoucher:show-profile-picture'

const showProfilePictureState = ref(true)
let initialized = false

function initialize() {
  if (initialized || typeof window === 'undefined') {
    return
  }

  const saved = window.localStorage.getItem(STORAGE_KEY)
  if (saved === 'false') {
    showProfilePictureState.value = false
  }

  initialized = true
}

function setShowProfilePicture(value: boolean) {
  showProfilePictureState.value = value

  if (typeof window !== 'undefined') {
    window.localStorage.setItem(STORAGE_KEY, String(value))
  }
}

export function useProfilePreferences() {
  initialize()

  return {
    showProfilePicture: computed(() => showProfilePictureState.value),
    setShowProfilePicture
  }
}
