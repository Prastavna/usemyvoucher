<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import VoucherCard from '@/components/VoucherCard.vue'
import supabase from '@/lib/supabase'
import type { Tables } from '@/types/supabase-generated'

const router = useRouter()
const auth = useAuth()

const loading = ref(true)
const errorMessage = ref('')
const vouchers = ref<Tables<'vouchers'>[]>([])

const search = ref('')
const category = ref('all')
const sortBy = ref<'newest' | 'most_used' | 'expiring_soon'>('newest')

const categoryOptions = computed(() => {
  const values = new Set<string>()
  for (const voucher of vouchers.value) {
    if (voucher.category) {
      values.add(voucher.category)
    }
  }

  return ['all', ...Array.from(values).sort((a, b) => a.localeCompare(b))]
})

const filteredVouchers = computed(() => {
  const byText = vouchers.value.filter((voucher) => {
    if (!search.value.trim()) {
      return true
    }

    return voucher.merchant_name.toLowerCase().includes(search.value.trim().toLowerCase())
  })

  const byCategory = byText.filter((voucher) => {
    if (category.value === 'all') {
      return true
    }

    return voucher.category === category.value
  })

  return byCategory.sort((a, b) => {
    if (sortBy.value === 'most_used') {
      return (b.use_count || 0) - (a.use_count || 0)
    }

    if (sortBy.value === 'expiring_soon') {
      const first = a.expiry_date ? new Date(a.expiry_date).getTime() : Number.MAX_SAFE_INTEGER
      const second = b.expiry_date ? new Date(b.expiry_date).getTime() : Number.MAX_SAFE_INTEGER
      return first - second
    }

    const first = a.created_at ? new Date(a.created_at).getTime() : 0
    const second = b.created_at ? new Date(b.created_at).getTime() : 0
    return second - first
  })
})

async function loadVouchers() {
  loading.value = true
  errorMessage.value = ''

  const { data, error } = await supabase
    .from('vouchers')
    .select('*')
    .eq('is_active', true)
    .is('deleted_at', null)

  if (error) {
    loading.value = false
    errorMessage.value = error.message
    return
  }

  let visibleVouchers = data.filter((voucher) => {
    return (voucher.use_count || 0) < (voucher.max_uses || 1)
  })

  if (auth.user.value) {
    const { data: usageData, error: usageError } = await supabase
      .from('voucher_uses')
      .select('voucher_id')
      .eq('user_id', auth.user.value.id)

    if (usageError) {
      loading.value = false
      errorMessage.value = usageError.message
      return
    }

    const usedVoucherIds = new Set(usageData.map((usage) => usage.voucher_id))
    visibleVouchers = visibleVouchers.filter((voucher) => !usedVoucherIds.has(voucher.id))
  }

  vouchers.value = visibleVouchers
  loading.value = false
}

function openVoucher(id: string) {
  router.push(`/voucher/${id}`)
}

onMounted(loadVouchers)

watch(
  () => auth.user.value?.id,
  () => {
    loadVouchers()
  }
)
</script>

<template>
  <section class="page-shell">
    <div class="page-head">
      <h1>Browse vouchers</h1>
      <p>Find active coupon codes shared by the community.</p>
    </div>

    <div class="toolbar">
      <input v-model="search" type="search" placeholder="Search by merchant" aria-label="Search vouchers" />
      <select v-model="category" aria-label="Filter by category">
        <option v-for="value in categoryOptions" :key="value" :value="value">
          {{ value === 'all' ? 'All categories' : value }}
        </option>
      </select>
      <select v-model="sortBy" aria-label="Sort vouchers">
        <option value="newest">Newest</option>
        <option value="most_used">Most used</option>
        <option value="expiring_soon">Expiring soon</option>
      </select>
    </div>

    <p v-if="errorMessage" class="error-state">Failed to load vouchers: {{ errorMessage }}</p>

    <div v-if="loading" class="voucher-grid" aria-label="Loading vouchers">
      <div v-for="item in 6" :key="item" class="skeleton-card" />
    </div>

    <div v-else-if="filteredVouchers.length" class="voucher-grid">
      <VoucherCard v-for="voucher in filteredVouchers" :key="voucher.id" :voucher="voucher" @open="openVoucher" />
    </div>

    <div v-else class="empty-state">
      <h2>No vouchers found</h2>
      <p>Try another search term or category, or check back soon.</p>
    </div>
  </section>
</template>
