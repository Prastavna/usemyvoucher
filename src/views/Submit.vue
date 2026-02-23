<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'
import supabase from '@/lib/supabase'

const router = useRouter()
const auth = useAuth()
const toast = useToast()

const loading = ref(false)

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
    toast.error('Please sign in first')
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
  <section class="page-shell narrow">
    <div class="page-head">
      <h1>Submit a voucher</h1>
      <p>Share unused codes so someone else can benefit.</p>
    </div>

    <form class="form-grid" @submit.prevent="submitVoucher">
      <label class="field">
        <span>Merchant name *</span>
        <input v-model="form.merchant_name" maxlength="120" required aria-label="Merchant name" />
      </label>

      <label class="field">
        <span>Voucher code *</span>
        <input v-model="form.voucher_code" maxlength="120" required aria-label="Voucher code" />
      </label>

      <label class="field">
        <span>Description</span>
        <textarea v-model="form.description" rows="3" maxlength="500" aria-label="Description" />
      </label>

      <label class="field">
        <span>Discount value</span>
        <input v-model="form.discount_value" maxlength="80" placeholder="e.g. 20% OFF" aria-label="Discount value" />
      </label>

      <label class="field">
        <span>Expiry date</span>
        <input v-model="form.expiry_date" type="date" aria-label="Expiry date" />
      </label>

      <label class="field">
        <span>Category</span>
        <input v-model="form.category" maxlength="80" placeholder="Food, Fashion, Travel..." aria-label="Category" />
      </label>

      <label class="field">
        <span>Max uses</span>
        <input v-model.number="form.max_uses" type="number" min="1" aria-label="Maximum uses" />
      </label>

      <button type="submit" class="primary" :disabled="loading" aria-label="Submit voucher form">
        {{ loading ? 'Submitting...' : 'Submit voucher' }}
      </button>
    </form>
  </section>
</template>
