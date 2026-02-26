<script setup lang="ts">
import { computed, ref } from 'vue'
import type { Tables } from '@/types/supabase-generated'

type VoucherPreview = Pick<
  Tables<'vouchers'>,
  'id' | 'merchant_name' | 'description' | 'discount_value' | 'category' | 'expiry_date' | 'use_count' | 'max_uses'
>

const props = defineProps<{
  voucher: VoucherPreview
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

const showDescription = ref(false)

const descriptionText = computed(() => {
  return props.voucher.description?.trim() || 'No description provided.'
})

function toggleDescription() {
  showDescription.value = !showDescription.value
}
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
      <div class="flex items-start justify-between gap-2">
        <h3 class="text-lg font-semibold text-stone-900">{{ voucher.merchant_name }}</h3>
        <button
          type="button"
          class="inline-flex size-6 shrink-0 items-center justify-center rounded-full border border-stone-300 bg-stone-50 text-xs font-bold text-stone-700 transition hover:border-teal-400 hover:text-teal-700"
          aria-label="Show voucher description"
          @click.stop="toggleDescription"
          @keyup.enter.stop
        >
          i
        </button>
      </div>
      <p class="mt-1 text-sm font-semibold text-teal-700">{{ voucher.discount_value || 'Offer available' }}</p>
      <p
        v-if="showDescription"
        class="mt-2 rounded-md border border-stone-200 bg-stone-50 px-2 py-1 text-xs text-stone-700"
      >
        {{ descriptionText }}
      </p>
    </div>
    <p class="text-sm text-stone-600">Category: {{ voucher.category || 'General' }}</p>
    <p class="text-sm text-stone-600">Expiry: {{ expiryText }}</p>
    <p class="text-sm text-stone-600">Uses: {{ voucher.use_count || 0 }} / {{ voucher.max_uses || 1 }}</p>
  </article>
</template>
