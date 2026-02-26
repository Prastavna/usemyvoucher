import { computed, ref, watch } from 'vue'
import { useAuth } from '@/composables/useAuth'
import supabase from '@/lib/supabase'

const showProfilePictureState = ref(true)
let initialized = false

async function loadShowProfilePicture(userId?: string) {
  if (!userId) {
    showProfilePictureState.value = true
    return
  }

  const { data, error } = await supabase
    .from('profiles')
    .select('show_profile_picture')
    .eq('id', userId)
    .single()

  if (error) {
    return
  }

  showProfilePictureState.value = data.show_profile_picture
}

async function setShowProfilePicture(value: boolean) {
  const auth = useAuth()
  const userId = auth.user.value?.id
  const previousValue = showProfilePictureState.value
  showProfilePictureState.value = value

  if (!userId) {
    return
  }

  const { error } = await supabase
    .from('profiles')
    .update({ show_profile_picture: value })
    .eq('id', userId)

  if (error) {
    showProfilePictureState.value = previousValue
  }
}

function initialize() {
  if (initialized) {
    return
  }

  const auth = useAuth()

  watch(
    () => auth.user.value?.id,
    (userId) => {
      void loadShowProfilePicture(userId)
    },
    { immediate: true }
  )

  initialized = true
}

export function useProfilePreferences() {
  initialize()

  return {
    showProfilePicture: computed(() => showProfilePictureState.value),
    setShowProfilePicture
  }
}
