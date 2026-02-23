<script setup lang="ts">
import { useAuth } from '@/composables/useAuth'
import { useLoginPrompt } from '@/composables/useLoginPrompt'
import { useToast } from '@/composables/useToast'

const auth = useAuth()
const toast = useToast()
const prompt = useLoginPrompt()

async function startGoogleSignIn() {
  prompt.closeLoginPrompt()

  try {
    await auth.signInWithGoogle()
  } catch (error) {
    toast.error(error instanceof Error ? error.message : 'Could not start Google sign-in')
  }
}
</script>

<template>
  <div
    v-if="prompt.open.value"
    class="modal-backdrop"
    role="dialog"
    aria-modal="true"
    aria-label="Sign in required dialog"
    @click.self="prompt.closeLoginPrompt"
  >
    <div class="modal-panel login-modal">
      <h3>Sign in required</h3>
      <p>{{ prompt.message.value }}</p>
      <div class="actions">
        <button type="button" class="secondary" @click="prompt.closeLoginPrompt">Not now</button>
        <button type="button" class="primary" @click="startGoogleSignIn">Sign in with Google</button>
      </div>
    </div>
  </div>
</template>
