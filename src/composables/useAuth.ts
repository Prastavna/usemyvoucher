import type { Session, User } from '@supabase/supabase-js'
import { computed, reactive } from 'vue'
import supabase from '@/lib/supabase'

const state = reactive({
  user: null as User | null,
  session: null as Session | null,
  loading: true,
  initialized: false
})

let authListenerBound = false

async function ensureProfile(user: User) {
  if (!user.email) {
    return
  }

  const { error } = await supabase
    .from('profiles')
    .upsert(
      {
        id: user.id,
        email: user.email,
        avatar_url: user.user_metadata.avatar_url ?? user.user_metadata.picture ?? null
      },
      {
        onConflict: 'id'
      }
    )

  if (error) {
    throw error
  }
}

async function syncProfile() {
  if (!state.user) {
    return
  }

  await ensureProfile(state.user)
}

async function fetchUser() {
  const { data, error } = await supabase.auth.getUser()
  if (error) {
    throw error
  }

  state.user = data.user
  return data.user
}

async function initializeAuth() {
  if (state.initialized) {
    return
  }

  try {
    const { data, error } = await supabase.auth.getSession()
    if (!error) {
      state.session = data.session
      state.user = data.session?.user ?? null
      if (state.user) {
        void ensureProfile(state.user).catch((profileError) => {
          console.error('Failed to sync user profile during auth init', profileError)
        })
      }
    }

    if (!authListenerBound) {
      supabase.auth.onAuthStateChange((_event, session) => {
        state.session = session
        state.user = session?.user ?? null
        if (state.user) {
          void ensureProfile(state.user).catch((profileError) => {
            console.error('Failed to sync user profile after auth change', profileError)
          })
        }
      })
      authListenerBound = true
    }

    state.initialized = true
  } finally {
    state.loading = false
  }
}

async function signInWithGoogle() {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: window.location.origin
    }
  })

  if (error) {
    throw error
  }
}

async function signOut() {
  const { error } = await supabase.auth.signOut()
  if (error) {
    throw error
  }
}

export function useAuth() {
  return {
    user: computed(() => state.user),
    session: computed(() => state.session),
    loading: computed(() => state.loading),
    isAuthenticated: computed(() => Boolean(state.user)),
    initializeAuth,
    syncProfile,
    fetchUser,
    signInWithGoogle,
    signOut
  }
}
