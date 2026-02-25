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
  <section class="mx-auto max-w-6xl space-y-4">
    <div class="space-y-1">
      <h1 class="text-3xl font-bold tracking-tight text-stone-900">My vouchers</h1>
      <p class="text-stone-600">Track your submitted vouchers, usage, and status.</p>
    </div>

    <p v-if="loading" class="text-stone-600">Loading your vouchers...</p>
    <p v-else-if="errorMessage" class="rounded-md border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-800">
      Failed to load vouchers: {{ errorMessage }}
    </p>

    <div v-else-if="withStatus.length" class="grid grid-cols-[repeat(auto-fill,minmax(240px,1fr))] gap-3">
      <article v-for="item in withStatus" :key="item.voucher.id" class="space-y-2 rounded-md border border-stone-500 bg-white p-4 shadow-sm">
        <h3 class="text-lg font-semibold text-stone-900">{{ item.voucher.merchant_name }}</h3>
        <p class="text-sm text-stone-600">Status: <strong>{{ item.status }}</strong></p>
        <p class="text-sm text-stone-600">Uses: {{ item.voucher.use_count || 0 }} / {{ item.voucher.max_uses || 1 }}</p>
        <p class="text-sm text-stone-600">Reports: {{ item.voucher.report_count || 0 }}</p>
        <div class="flex flex-wrap gap-2">
          <UButton type="button" color="neutral" variant="soft" @click="openVoucher(item.voucher.id)">View</UButton>
          <UButton
            type="button"
            color="error"
            variant="soft"
            @click="softDelete(item.voucher.id)"
            :disabled="Boolean(item.voucher.deleted_at)"
          >
            {{ item.voucher.deleted_at ? 'Deleted' : 'Delete' }}
          </UButton>
        </div>
      </article>
    </div>

    <div v-else class="rounded-md border border-stone-400 bg-amber-50 px-6 py-10 text-center">
      <h2 class="text-xl font-semibold text-stone-900">No vouchers yet</h2>
      <p class="mt-2 text-stone-600">Submit your first voucher to start earning points.</p>
      <RouterLink class="mt-4 inline-flex rounded-md bg-teal-700 px-4 py-2 font-semibold text-white hover:bg-teal-800" to="/submit">
        Go to submit page
      </RouterLink>
    </div>
  </section>
</template>
