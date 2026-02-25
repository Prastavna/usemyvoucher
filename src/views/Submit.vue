<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { DEFAULT_VOUCHER_CATEGORIES } from '@/constants/categories'
import { useLoginPrompt } from '@/composables/useLoginPrompt'
import { useToast } from '@/composables/useToast'
import supabase from '@/lib/supabase'

const router = useRouter()
const auth = useAuth()
const prompt = useLoginPrompt()
const toast = useToast()

const loading = ref(false)

const controlClass =
  'w-full rounded-md border border-stone-300 bg-white px-3 py-2 text-sm text-stone-800 shadow-sm outline-none transition focus:border-teal-500 focus:ring-2 focus:ring-teal-200'

const form = reactive({
  merchant_name: '',
  voucher_code: '',
  description: '',
  discount_value: '',
  expiry_date: '',
  category: '',
  max_uses: 1
})

function validateForm() {
  if (!form.merchant_name.trim()) {
    return 'Merchant name is required'
  }

  if (!form.voucher_code.trim()) {
    return 'Voucher code is required'
  }

  if (form.max_uses < 1) {
    return 'Max uses must be at least 1'
  }

  return ''
}

async function submitVoucher() {
  if (!auth.user.value) {
    prompt.openLoginPrompt('Sign in to submit a voucher.')
    return
  }

  const validationError = validateForm()
  if (validationError) {
    toast.error(validationError)
    return
  }

  loading.value = true

  const { data, error } = await supabase
    .from('vouchers')
    .insert({
      merchant_name: form.merchant_name.trim(),
      voucher_code: form.voucher_code.trim(),
      description: form.description.trim() || null,
      discount_value: form.discount_value.trim() || null,
      expiry_date: form.expiry_date || null,
      category: form.category.trim() || null,
      max_uses: form.max_uses,
      user_id: auth.user.value.id,
      is_active: true
    })
    .select('id')
    .single()

  loading.value = false

  if (error) {
    toast.error(error.message)
    return
  }

  form.merchant_name = ''
  form.voucher_code = ''
  form.description = ''
  form.discount_value = ''
  form.expiry_date = ''
  form.category = ''
  form.max_uses = 1

  toast.success('Voucher submitted successfully')
  await router.push(`/voucher/${data.id}`)
}
</script>

<template>
  <section class="mx-auto flex max-w-3xl flex-col gap-4">
    <div class="space-y-1">
      <h1 class="text-3xl font-bold tracking-tight text-stone-900">Submit a voucher</h1>
      <p class="text-stone-600">Share unused codes so someone else can benefit.</p>
    </div>

    <form class="grid gap-3" @submit.prevent="submitVoucher">
      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Merchant name *</span>
        <input v-model="form.merchant_name" :class="controlClass" maxlength="120" required aria-label="Merchant name" />
      </label>

      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Voucher code *</span>
        <input v-model="form.voucher_code" :class="controlClass" maxlength="120" required aria-label="Voucher code" />
      </label>

      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Description</span>
        <textarea v-model="form.description" :class="controlClass" rows="3" maxlength="500" aria-label="Description" />
      </label>

      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Discount value</span>
        <input
          v-model="form.discount_value"
          :class="controlClass"
          maxlength="80"
          placeholder="e.g. 20% OFF"
          aria-label="Discount value"
        />
      </label>

      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Expiry date</span>
        <input v-model="form.expiry_date" :class="controlClass" type="date" aria-label="Expiry date" />
      </label>

      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Category</span>
        <select v-model="form.category" :class="controlClass" aria-label="Category">
          <option value="">Select category</option>
          <option v-for="value in DEFAULT_VOUCHER_CATEGORIES" :key="value" :value="value">
            {{ value }}
          </option>
        </select>
      </label>

      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Max uses</span>
        <input v-model.number="form.max_uses" :class="controlClass" type="number" min="1" aria-label="Maximum uses" />
      </label>

      <UButton type="submit" color="primary" :loading="loading" :disabled="loading" class="w-fit" aria-label="Submit voucher form">
        {{ loading ? 'Submitting...' : 'Submit voucher' }}
      </UButton>
    </form>
  </section>
</template>
