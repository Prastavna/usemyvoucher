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

  await supabase.from('profiles').upsert({
    id: user.id,
    email: user.email,
    display_name: user.user_metadata.full_name ?? user.user_metadata.name ?? null,
    avatar_url: user.user_metadata.avatar_url ?? null
  })
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

  const { data, error } = await supabase.auth.getSession()
  if (!error) {
    state.session = data.session
    state.user = data.session?.user ?? null
    if (state.user) {
      await ensureProfile(state.user)
    }
  }

  if (!authListenerBound) {
    supabase.auth.onAuthStateChange(async (_event, session) => {
      state.session = session
      state.user = session?.user ?? null
      if (state.user) {
        await ensureProfile(state.user)
      }
    })
    authListenerBound = true
  }

  state.initialized = true
  state.loading = false
}

async function signInWithGoogle() {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${window.location.origin}`
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
    fetchUser,
    signInWithGoogle,
    signOut
  }
}
