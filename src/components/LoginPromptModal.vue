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
    class="fixed inset-0 z-40 grid place-items-center bg-slate-900/45 p-4"
    role="dialog"
    aria-modal="true"
    aria-label="Sign in required dialog"
    @click.self="prompt.closeLoginPrompt"
  >
    <div class="w-full max-w-md space-y-3 rounded-lg border border-stone-500 bg-white p-4 shadow-lg">
      <h3 class="text-lg font-semibold text-stone-900">Sign in required</h3>
      <p class="text-stone-600">{{ prompt.message.value }}</p>
      <div class="flex flex-wrap gap-2">
        <UButton type="button" color="neutral" variant="soft" @click="prompt.closeLoginPrompt">Not now</UButton>
        <UButton type="button" color="primary" @click="startGoogleSignIn">Sign in with Google</UButton>
      </div>
    </div>
  </div>
</template>
