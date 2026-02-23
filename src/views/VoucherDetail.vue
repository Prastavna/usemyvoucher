<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import ReportModal from '@/components/ReportModal.vue'
import { useAuth } from '@/composables/useAuth'
import { useLoginPrompt } from '@/composables/useLoginPrompt'
import { useToast } from '@/composables/useToast'
import supabase from '@/lib/supabase'
import type { Tables } from '@/types/supabase-generated'

const route = useRoute()
const auth = useAuth()
const prompt = useLoginPrompt()
const toast = useToast()

const loading = ref(true)
const errorMessage = ref('')
const voucher = ref<Tables<'vouchers'> | null>(null)
const reveal = ref(false)
const hasUsed = ref(false)
const reportOpen = ref(false)

const voucherId = computed(() => route.params.id as string)

const usageLimitReached = computed(() => {
  if (!voucher.value) {
    return false
  }

  return (voucher.value.use_count || 0) >= (voucher.value.max_uses || 1)
})

const disableUseButton = computed(() => hasUsed.value || usageLimitReached.value)

async function loadVoucher() {
  loading.value = true
  errorMessage.value = ''

  const { data, error } = await supabase
    .from('vouchers')
    .select('*')
    .eq('id', voucherId.value)
    .single()

  if (error) {
    loading.value = false
    errorMessage.value = error.message
    return
  }

  voucher.value = data

  if (auth.user.value) {
    const used = await supabase
      .from('voucher_uses')
      .select('id')
      .eq('voucher_id', voucherId.value)
      .eq('user_id', auth.user.value.id)
      .limit(1)

    hasUsed.value = (used.data?.length || 0) > 0
  }

  loading.value = false
}

async function revealCode() {
  if (!voucher.value || reveal.value) {
    return
  }

  if (!auth.user.value) {
    prompt.openLoginPrompt('Sign in to reveal and copy voucher codes.')
    return
  }

  reveal.value = true

  await supabase.from('voucher_views').insert({
    voucher_id: voucher.value.id,
    viewer_id: auth.user.value.id
  })
}

async function copyCode() {
  if (!voucher.value) {
    return
  }

  try {
    await navigator.clipboard.writeText(voucher.value.voucher_code)
    toast.success('Voucher code copied')
  } catch {
    toast.error('Copy failed. Please copy manually.')
  }
}

async function markUsed() {
  if (!voucher.value || disableUseButton.value) {
    return
  }

  if (!auth.user.value) {
    prompt.openLoginPrompt('Sign in to mark voucher usage and earn points.')
    return
  }

  const { error } = await supabase.from('voucher_uses').insert({
    voucher_id: voucher.value.id,
    user_id: auth.user.value.id
  })

  if (error) {
    if ('code' in error && error.code === '23505') {
      hasUsed.value = true
      toast.info('You already marked this voucher as used')
      return
    }

    toast.error(error.message)
    return
  }

  hasUsed.value = true
  voucher.value.use_count = (voucher.value.use_count || 0) + 1
  toast.success('Marked as used. Thanks for contributing usage data.')
}

function openReportModal() {
  if (!auth.user.value) {
    prompt.openLoginPrompt('Sign in to report voucher issues.')
    return
  }

  reportOpen.value = true
}

onMounted(loadVoucher)
</script>

<template>
  <section class="page-shell">
    <p v-if="loading">Loading voucher...</p>
    <p v-else-if="errorMessage" class="error-state">Failed to load voucher: {{ errorMessage }}</p>

    <article v-else-if="voucher" class="detail-card">
      <h1>{{ voucher.merchant_name }}</h1>
      <p>{{ voucher.description || 'No description provided.' }}</p>

      <div class="detail-grid">
        <p><strong>Discount:</strong> {{ voucher.discount_value || 'N/A' }}</p>
        <p><strong>Category:</strong> {{ voucher.category || 'General' }}</p>
        <p><strong>Expiry:</strong> {{ voucher.expiry_date ? new Date(voucher.expiry_date).toLocaleDateString() : 'No expiry' }}</p>
        <p><strong>Uses:</strong> {{ voucher.use_count || 0 }} / {{ voucher.max_uses || 1 }}</p>
      </div>

      <div class="code-box">
        <p class="code-value">{{ reveal ? voucher.voucher_code : '••••••••••' }}</p>
        <div class="actions">
          <button type="button" class="primary" @click="revealCode" :disabled="reveal">Reveal code</button>
          <button type="button" class="secondary" @click="copyCode" :disabled="!reveal">Copy code</button>
        </div>
      </div>

      <div class="actions">
        <button type="button" class="primary" @click="markUsed" :disabled="disableUseButton">
          {{ hasUsed ? 'Already used' : usageLimitReached ? 'Usage limit reached' : 'I used this code' }}
        </button>
        <button type="button" class="secondary" @click="openReportModal">Report issue</button>
      </div>
    </article>

    <ReportModal
      :open="reportOpen"
      :voucher-id="voucherId"
      @close="reportOpen = false"
      @submitted="loadVoucher"
    />
  </section>
</template>
