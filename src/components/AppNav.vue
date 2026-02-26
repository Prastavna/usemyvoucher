<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'
import supabase from '@/lib/supabase'
import type { Tables } from '@/types/supabase-generated'

const auth = useAuth()
const toast = useToast()
const router = useRouter()
const menuOpen = ref(false)

type ProfileSummary = Pick<Tables<'profiles'>, 'display_name' | 'avatar_url'>
const profile = ref<ProfileSummary | null>(null)

const displayName = computed(() => {
  const user = auth.user.value
  if (!user) {
    return ''
  }

  return profile.value?.display_name?.trim() || user.user_metadata.full_name || user.email || 'User'
})

const avatarUrl = computed(() => profile.value?.avatar_url || (auth.user.value?.user_metadata.avatar_url as string | undefined))

const navLinkClass =
  'rounded-md border border-stone-300 bg-white px-3 py-1.5 text-sm font-medium text-stone-700 transition hover:border-teal-500 hover:text-teal-700'
const navLinkActiveClass = '!border-teal-300 !bg-teal-50 !text-teal-800'

async function onSignOut() {
  try {
    await auth.signOut()
    toast.success('Signed out successfully')
    await router.push('/')
  } catch (error) {
    toast.error(error instanceof Error ? error.message : 'Failed to sign out')
  }
}

async function onSignIn() {
  try {
    await auth.signInWithGoogle()
  } catch (error) {
    toast.error(error instanceof Error ? error.message : 'Could not start Google sign-in')
  }
}

async function loadProfileSummary() {
  if (!auth.user.value) {
    profile.value = null
    return
  }

  const { data, error } = await supabase
    .from('profiles')
    .select('display_name, avatar_url')
    .eq('id', auth.user.value.id)
    .single()

  if (error) {
    return
  }

  profile.value = data
}

watch(
  () => auth.user.value?.id,
  () => {
    loadProfileSummary()
  },
  { immediate: true }
)
</script>

<template>
  <header class="sticky top-0 z-20 border-b border-stone-300/80 bg-amber-50/85 backdrop-blur">
    <div class="mx-auto flex max-w-6xl flex-wrap items-center gap-3 px-4 py-3">
      <RouterLink to="/" class="inline-flex items-center gap-2 font-bold text-stone-900" aria-label="Go to browse page">
        <span
          class="inline-grid w-6 place-items-center rounded-md text-xs font-semibold text-white"
        >
          <img src="../assets/usemyvoucher.svg" alt="Use My Voucher Logo" />
        </span>
        <span class="text-emerald-600">Use My Voucher</span>
      </RouterLink>

      <button
        type="button"
        class="ml-auto inline-flex rounded-md border border-stone-400 bg-white px-3 py-1 text-lg md:hidden"
        aria-label="Toggle navigation"
        @click="menuOpen = !menuOpen"
      >
        ☰
      </button>

      <nav
        class="w-full flex-wrap items-center gap-2 md:flex md:w-auto md:flex-1 md:justify-center"
        :class="{ hidden: !menuOpen, flex: menuOpen }"
        aria-label="Main navigation"
      >
        <RouterLink to="/" :class="navLinkClass" :active-class="navLinkActiveClass" @click="menuOpen = false">Browse</RouterLink>
        <RouterLink to="/submit" :class="navLinkClass" :active-class="navLinkActiveClass" @click="menuOpen = false">Submit</RouterLink>
        <RouterLink to="/my-vouchers" :class="navLinkClass" :active-class="navLinkActiveClass" @click="menuOpen = false">My Vouchers</RouterLink>
        <RouterLink to="/leaderboard" :class="navLinkClass" :active-class="navLinkActiveClass" @click="menuOpen = false">Leaderboard</RouterLink>
        <RouterLink to="/profile" :class="navLinkClass" :active-class="navLinkActiveClass" @click="menuOpen = false">Profile</RouterLink>
      </nav>

      <div class="ml-auto flex w-full items-center gap-2 md:w-auto" v-if="auth.user.value">
        <img v-if="avatarUrl" :src="avatarUrl" alt="User avatar" class="size-8 rounded-full object-cover" />
        <span class="truncate text-sm font-medium text-stone-700">{{ displayName }}</span>
        <UButton color="neutral" variant="ghost" size="sm" @click="onSignOut" aria-label="Sign out">Sign Out</UButton>
      </div>

      <div class="ml-auto w-full md:w-auto" v-else>
        <UButton color="primary" size="sm" @click="onSignIn" aria-label="Sign in with Google">Sign in with Google</UButton>
      </div>
    </div>
  </header>
</template>
