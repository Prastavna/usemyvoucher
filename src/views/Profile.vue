<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'
import supabase from '@/lib/supabase'
import type { Tables } from '@/types/supabase-generated'

const auth = useAuth()
const toast = useToast()

const loading = ref(true)
const errorMessage = ref('')
const profile = ref<Tables<'profiles'> | null>(null)
const vouchersSubmitted = ref(0)
const vouchersUsed = ref(0)
const usesByOthers = ref(0)
const displayNameDraft = ref('')
const savingName = ref(false)

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

  savingName.value = true
  const { error } = await supabase
    .from('profiles')
    .update({ display_name: displayNameDraft.value.trim() || null })
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
</script>

<template>
  <section class="page-shell narrow">
    <div class="page-head">
      <h1>Profile</h1>
      <p>Your account details and contribution stats.</p>
    </div>

    <p v-if="loading">Loading profile...</p>
    <p v-else-if="errorMessage" class="error-state">Failed to load profile: {{ errorMessage }}</p>

    <article v-else-if="profile" class="profile-card">
      <img v-if="profile.avatar_url" :src="profile.avatar_url" alt="Profile avatar" class="profile-avatar" />
      <p><strong>Email:</strong> {{ profile.email }}</p>
      <p><strong>Points:</strong> {{ profile.points || 0 }}</p>
      <p><strong>Joined:</strong> {{ joinedDate }}</p>

      <div class="stats-grid">
        <div>
          <p class="stat-label">Vouchers submitted</p>
          <p class="stat-value">{{ vouchersSubmitted }}</p>
        </div>
        <div>
          <p class="stat-label">Vouchers used</p>
          <p class="stat-value">{{ vouchersUsed }}</p>
        </div>
        <div>
          <p class="stat-label">Used by others</p>
          <p class="stat-value">{{ usesByOthers }}</p>
        </div>
      </div>

      <label class="field">
        <span>Edit display name</span>
        <input v-model="displayNameDraft" maxlength="120" aria-label="Edit display name" />
      </label>
      <button type="button" class="primary" @click="saveDisplayName" :disabled="savingName">
        {{ savingName ? 'Saving...' : 'Save display name' }}
      </button>
    </article>
  </section>
</template>
