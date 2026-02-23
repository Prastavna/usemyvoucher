<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'

const auth = useAuth()
const toast = useToast()
const router = useRouter()
const menuOpen = ref(false)

const displayName = computed(() => {
  const user = auth.user.value
  if (!user) {
    return ''
  }

  return user.user_metadata.full_name ?? user.email ?? 'User'
})

const avatarUrl = computed(() => auth.user.value?.user_metadata.avatar_url as string | undefined)

async function onSignOut() {
  try {
    await auth.signOut()
    toast.success('Signed out successfully')
    await router.push('/browse')
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
</script>

<template>
  <header class="site-nav">
    <div class="site-nav-inner">
      <RouterLink to="/browse" class="brand" aria-label="Go to browse page">
        <span class="brand-mark">UMV</span>
        <span class="brand-name">UseMyVoucher</span>
      </RouterLink>

      <button type="button" class="mobile-toggle" aria-label="Toggle navigation" @click="menuOpen = !menuOpen">
        ☰
      </button>

      <nav class="nav-links" :class="{ open: menuOpen }" aria-label="Main navigation">
        <RouterLink to="/browse" @click="menuOpen = false">Browse</RouterLink>
        <RouterLink to="/submit" @click="menuOpen = false">Submit</RouterLink>
        <RouterLink to="/my-vouchers" @click="menuOpen = false">My Vouchers</RouterLink>
        <RouterLink to="/leaderboard" @click="menuOpen = false">Leaderboard</RouterLink>
        <RouterLink to="/profile" @click="menuOpen = false">Profile</RouterLink>
      </nav>

      <div class="user-menu" v-if="auth.user.value">
        <img v-if="avatarUrl" :src="avatarUrl" alt="User avatar" class="avatar" />
        <span class="user-name">{{ displayName }}</span>
        <button type="button" class="link-button" @click="onSignOut" aria-label="Sign out">
          Sign Out
        </button>
      </div>

      <div class="user-menu" v-else>
        <button type="button" class="primary" @click="onSignIn" aria-label="Sign in with Google">
          Sign in with Google
        </button>
      </div>
    </div>
  </header>
</template>
