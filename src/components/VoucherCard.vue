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
  <article class="voucher-card" tabindex="0" role="button" @click="emit('open', voucher.id)" @keyup.enter="emit('open', voucher.id)">
    <div class="voucher-card-top">
      <h3>{{ voucher.merchant_name }}</h3>
      <p class="discount">{{ voucher.discount_value || 'Offer available' }}</p>
    </div>
    <p class="meta">Category: {{ voucher.category || 'General' }}</p>
    <p class="meta">Expiry: {{ expiryText }}</p>
    <p class="meta">Uses: {{ voucher.use_count || 0 }} / {{ voucher.max_uses || 1 }}</p>
  </article>
</template>
