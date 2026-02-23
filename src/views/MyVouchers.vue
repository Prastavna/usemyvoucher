<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'
import supabase from '@/lib/supabase'
import type { Tables } from '@/types/supabase-generated'

const router = useRouter()
const auth = useAuth()
const toast = useToast()

const loading = ref(true)
const errorMessage = ref('')
const vouchers = ref<Tables<'vouchers'>[]>([])

const withStatus = computed(() => {
  return vouchers.value.map((voucher) => {
    let status = 'Active'
    if (voucher.deleted_at) {
      status = 'Deleted'
    } else if ((voucher.report_count || 0) > 0) {
      status = 'Reported'
    }

    return { voucher, status }
  })
})

async function loadMyVouchers() {
  if (!auth.user.value) {
    loading.value = false
    return
  }

  loading.value = true
  errorMessage.value = ''

  const { data, error } = await supabase
    .from('vouchers')
    .select('*')
    .eq('user_id', auth.user.value.id)
    .order('created_at', { ascending: false })

  loading.value = false

  if (error) {
    errorMessage.value = error.message
    return
  }

  vouchers.value = data
}

async function softDelete(voucherId: string) {
  if (!auth.user.value) {
    return
  }

  const confirmed = window.confirm('Delete this voucher from active listings?')
  if (!confirmed) {
    return
  }

  const { error } = await supabase.rpc('soft_delete_voucher', {
    user_id_param: auth.user.value.id,
    voucher_id_param: voucherId
  })

  if (error) {
    toast.error(error.message)
    return
  }

  toast.success('Voucher deleted')
  await loadMyVouchers()
}

function openVoucher(id: string) {
  router.push(`/voucher/${id}`)
}

onMounted(loadMyVouchers)
</script>

<template>
  <section class="page-shell">
    <div class="page-head">
      <h1>My vouchers</h1>
      <p>Track your submitted vouchers, usage, and status.</p>
    </div>

    <p v-if="loading">Loading your vouchers...</p>
    <p v-else-if="errorMessage" class="error-state">Failed to load vouchers: {{ errorMessage }}</p>

    <div v-else-if="withStatus.length" class="my-voucher-grid">
      <article v-for="item in withStatus" :key="item.voucher.id" class="my-voucher-card">
        <h3>{{ item.voucher.merchant_name }}</h3>
        <p>Status: <strong>{{ item.status }}</strong></p>
        <p>Uses: {{ item.voucher.use_count || 0 }} / {{ item.voucher.max_uses || 1 }}</p>
        <p>Reports: {{ item.voucher.report_count || 0 }}</p>
        <div class="actions">
          <button type="button" class="secondary" @click="openVoucher(item.voucher.id)">View</button>
          <button
            type="button"
            class="danger"
            @click="softDelete(item.voucher.id)"
            :disabled="Boolean(item.voucher.deleted_at)"
          >
            {{ item.voucher.deleted_at ? 'Deleted' : 'Delete' }}
          </button>
        </div>
      </article>
    </div>

    <div v-else class="empty-state">
      <h2>No vouchers yet</h2>
      <p>Submit your first voucher to start earning points.</p>
      <RouterLink class="primary-link" to="/submit">Go to submit page</RouterLink>
    </div>
  </section>
</template>
