<script setup lang="ts">
import { computed, onActivated, onMounted, ref } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useProfilePreferences } from '@/composables/useProfilePreferences'
import { useToast } from '@/composables/useToast'
import supabase from '@/lib/supabase'
import type { Tables } from '@/types/supabase-generated'
import { containsProfanity } from '@/utils/profanity'

const auth = useAuth()
const toast = useToast()
const { showProfilePicture, setShowProfilePicture } = useProfilePreferences()

const loading = ref(true)
const errorMessage = ref('')
const profile = ref<Tables<'profiles'> | null>(null)
const vouchersSubmitted = ref(0)
const vouchersUsed = ref(0)
const usesByOthers = ref(0)
const displayNameDraft = ref('')
const savingName = ref(false)

const controlClass =
  'w-full rounded-md border border-stone-300 bg-white px-3 py-2 text-sm text-stone-800 shadow-sm outline-none transition focus:border-teal-500 focus:ring-2 focus:ring-teal-200'

const joinedDate = computed(() => {
  if (!profile.value?.created_at) {
    return 'Unknown'
  }

  return new Date(profile.value.created_at).toLocaleDateString()
})

async function loadProfile() {
  if (!auth.user.value) {
    loading.value = false
    return
  }

  loading.value = true
  errorMessage.value = ''

  const [profileResult, submittedResult, usedResult, myVoucherIdsResult] = await Promise.all([
    supabase.from('profiles').select('*').eq('id', auth.user.value.id).single(),
    supabase.from('vouchers').select('id', { count: 'exact', head: true }).eq('user_id', auth.user.value.id),
    supabase.from('voucher_uses').select('id', { count: 'exact', head: true }).eq('user_id', auth.user.value.id),
    supabase.from('vouchers').select('id').eq('user_id', auth.user.value.id)
  ])

  if (profileResult.error) {
    loading.value = false
    errorMessage.value = profileResult.error.message
    return
  }

  profile.value = profileResult.data
  displayNameDraft.value = profile.value.display_name || ''
  vouchersSubmitted.value = submittedResult.count || 0
  vouchersUsed.value = usedResult.count || 0

  const myVoucherIds = (myVoucherIdsResult.data || []).map((item) => item.id)
  if (myVoucherIds.length > 0) {
    const usesByOthersResult = await supabase
      .from('voucher_uses')
      .select('id', { count: 'exact', head: true })
      .in('voucher_id', myVoucherIds)
      .neq('user_id', auth.user.value.id)

    usesByOthers.value = usesByOthersResult.count || 0
  } else {
    usesByOthers.value = 0
  }

  loading.value = false
}

async function saveDisplayName() {
  if (!auth.user.value || !profile.value) {
    return
  }

  const nextDisplayName = displayNameDraft.value.trim()

  if (nextDisplayName && containsProfanity(nextDisplayName)) {
    toast.error('Please use a clean display name without profanity')
    return
  }

  savingName.value = true
  const { error } = await supabase
    .from('profiles')
    .update({ display_name: nextDisplayName || null })
    .eq('id', auth.user.value.id)

  savingName.value = false

  if (error) {
    toast.error(error.message)
    return
  }

  toast.success('Display name updated')
  await loadProfile()
}

onMounted(loadProfile)
onActivated(loadProfile)
</script>

<template>
  <section class="mx-auto flex max-w-3xl flex-col gap-4">
    <div class="space-y-1">
      <h1 class="text-3xl font-bold tracking-tight text-stone-900">Profile</h1>
      <p class="text-stone-600">Your account details and contribution stats.</p>
    </div>

    <p v-if="loading" class="text-stone-600">Loading profile...</p>
    <p v-else-if="errorMessage" class="rounded-md border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-800">
      Failed to load profile: {{ errorMessage }}
    </p>

    <article v-else-if="profile" class="space-y-3 rounded-md border border-stone-500 bg-white p-4 shadow-sm">
      <label class="inline-flex w-fit items-center gap-2 rounded-md border border-stone-200 bg-stone-50 px-3 py-2 text-sm text-stone-700">
        <input
          :checked="showProfilePicture"
          type="checkbox"
          class="size-4 accent-teal-700"
          @change="setShowProfilePicture(($event.target as HTMLInputElement).checked)"
        />
        Show my profile picture on leaderboard
      </label>

      <img v-if="profile.avatar_url" :src="profile.avatar_url" alt="Profile avatar" class="size-16 rounded-full object-cover" />
      <p><strong>Email:</strong> {{ profile.email }}</p>
      <p><strong>Points:</strong> {{ profile.points || 0 }}</p>
      <p><strong>Joined:</strong> {{ joinedDate }}</p>

      <div class="grid gap-2 sm:grid-cols-3">
        <div>
          <p class="text-sm text-stone-500">Vouchers submitted</p>
          <p class="text-xl font-bold text-stone-900">{{ vouchersSubmitted }}</p>
        </div>
        <div>
          <p class="text-sm text-stone-500">Vouchers used</p>
          <p class="text-xl font-bold text-stone-900">{{ vouchersUsed }}</p>
        </div>
        <div>
          <p class="text-sm text-stone-500">Used by others</p>
          <p class="text-xl font-bold text-stone-900">{{ usesByOthers }}</p>
        </div>
      </div>

      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Edit display name</span>
        <input v-model="displayNameDraft" :class="controlClass" maxlength="120" aria-label="Edit display name" />
      </label>
      <UButton type="button" color="primary" :loading="savingName" :disabled="savingName" class="w-fit" @click="saveDisplayName">
        {{ savingName ? 'Saving...' : 'Save display name' }}
      </UButton>
    </article>
  </section>
</template>
