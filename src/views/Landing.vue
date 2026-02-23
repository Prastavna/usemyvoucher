<script setup lang="ts">
import { onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'

const auth = useAuth()
const toast = useToast()
const route = useRoute()
const router = useRouter()

async function startGoogleSignIn() {
  try {
    await auth.signInWithGoogle()
  } catch (error) {
    toast.error(error instanceof Error ? error.message : 'Could not start Google sign-in')
  }
}

onMounted(() => {
  if (auth.isAuthenticated.value) {
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/browse'
    router.replace(redirect)
  }
})
</script>

<template>
  <section class="landing-wrap">
    <div class="landing-content">
      <p class="eyebrow">Pass it forward</p>
      <h1>Share unused vouchers. Help someone save today.</h1>
      <p>
        UseMyVoucher is a simple community board where members post real, unused discount codes.
        Sign in to browse, submit your extra vouchers, and earn points when others use them.
      </p>
      <UButton size="xl" color="neutral" @click="startGoogleSignIn" aria-label="Sign in with Google">
        Sign in with Google
      </UButton>
    </div>
  </section>
</template>
