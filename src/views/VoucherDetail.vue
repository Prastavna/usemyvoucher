<script setup lang="ts">
import { computed, onActivated, onMounted, ref, watch } from 'vue'
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
  reveal.value = false
  hasUsed.value = false

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
  await loadVoucher()
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
onActivated(loadVoucher)
watch(voucherId, loadVoucher)
</script>

<template>
  <section class="mx-auto max-w-6xl">
    <p v-if="loading" class="text-stone-600">Loading voucher...</p>
    <p v-else-if="errorMessage" class="rounded-md border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-800">
      Failed to load voucher: {{ errorMessage }}
    </p>

    <article v-else-if="voucher" class="space-y-4 rounded-md border border-stone-500 bg-white p-4 shadow-sm">
      <h1 class="text-3xl font-bold tracking-tight text-stone-900">{{ voucher.merchant_name }}</h1>
      <p class="text-stone-600">{{ voucher.description || 'No description provided.' }}</p>

      <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
        <p><strong>Discount:</strong> {{ voucher.discount_value || 'N/A' }}</p>
        <p><strong>Category:</strong> {{ voucher.category || 'General' }}</p>
        <p><strong>Expiry:</strong> {{ voucher.expiry_date ? new Date(voucher.expiry_date).toLocaleDateString() : 'No expiry' }}</p>
        <p><strong>Uses:</strong> {{ voucher.use_count || 0 }} / {{ voucher.max_uses || 1 }}</p>
      </div>

      <div class="space-y-3 rounded-md border border-stone-500 p-4">
        <p class="font-mono text-2xl font-bold tracking-[0.1em] text-stone-900">{{ reveal ? voucher.voucher_code : '••••••••••' }}</p>
        <div class="flex flex-wrap gap-2">
          <UButton type="button" color="primary" @click="revealCode" :disabled="reveal">Reveal code</UButton>
          <UButton type="button" color="neutral" variant="soft" @click="copyCode" :disabled="!reveal">Copy code</UButton>
        </div>
      </div>

      <div class="flex flex-wrap gap-2">
        <UButton type="button" color="primary" @click="markUsed" :disabled="disableUseButton">
          {{ hasUsed ? 'Already used' : usageLimitReached ? 'Usage limit reached' : 'I used this code' }}
        </UButton>
        <UButton type="button" color="neutral" variant="soft" @click="openReportModal">Report issue</UButton>
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
