<script setup lang="ts">
import { computed } from 'vue'
import type { Tables } from '@/types/supabase-generated'

const props = defineProps<{
  voucher: Tables<'vouchers'>
}>()

const emit = defineEmits<{
  open: [id: string]
}>()

const expiryText = computed(() => {
  if (!props.voucher.expiry_date) {
    return 'No expiry'
  }

  return new Date(props.voucher.expiry_date).toLocaleDateString()
})
</script>

<template>
  <article
    class="cursor-pointer space-y-1 rounded-md border border-stone-500 bg-white p-4 shadow-sm transition hover:border-stone-700"
    tabindex="0"
    role="button"
    @click="emit('open', voucher.id)"
    @keyup.enter="emit('open', voucher.id)"
  >
    <div>
      <h3 class="text-lg font-semibold text-stone-900">{{ voucher.merchant_name }}</h3>
      <p class="mt-1 text-sm font-semibold text-teal-700">{{ voucher.discount_value || 'Offer available' }}</p>
    </div>
    <p class="text-sm text-stone-600">Category: {{ voucher.category || 'General' }}</p>
    <p class="text-sm text-stone-600">Expiry: {{ expiryText }}</p>
    <p class="text-sm text-stone-600">Uses: {{ voucher.use_count || 0 }} / {{ voucher.max_uses || 1 }}</p>
  </article>
</template>
