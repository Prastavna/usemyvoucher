<script setup lang="ts">
import { ref, watch } from 'vue'
import supabase from '@/lib/supabase'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'

const props = defineProps<{
  open: boolean
  voucherId: string
}>()

const emit = defineEmits<{
  close: []
  submitted: []
}>()

const auth = useAuth()
const toast = useToast()

const reason = ref('Code does not work')
const details = ref('')
const loading = ref(false)

const controlClass =
  'w-full rounded-md border border-stone-300 bg-white px-3 py-2 text-sm text-stone-800 shadow-sm outline-none transition focus:border-teal-500 focus:ring-2 focus:ring-teal-200'

const reasons = [
  'Code does not work',
  'Expired',
  'Wrong info',
  'Duplicate',
  'Other'
]

watch(
  () => props.open,
  (isOpen) => {
    if (isOpen) {
      reason.value = 'Code does not work'
      details.value = ''
    }
  }
)

async function submitReport() {
  if (!auth.user.value) {
    toast.error('Please sign in to report a voucher')
    return
  }

  loading.value = true
  const fullReason = details.value.trim()
    ? `${reason.value}: ${details.value.trim()}`
    : reason.value

  const { error } = await supabase.from('voucher_reports').insert({
    voucher_id: props.voucherId,
    reporter_id: auth.user.value.id,
    reason: fullReason
  })

  loading.value = false

  if (error) {
    if ('code' in error && error.code === '23505') {
      toast.info('You already reported this voucher')
      emit('close')
      return
    }

    toast.error(error.message)
    return
  }

  toast.success('Report submitted. Thanks for helping keep listings clean.')
  emit('submitted')
  emit('close')
}
</script>

<template>
  <div
    v-if="open"
    class="fixed inset-0 z-40 grid place-items-center bg-slate-900/45 p-4"
    role="dialog"
    aria-modal="true"
    aria-label="Report voucher dialog"
  >
    <div class="w-full max-w-md space-y-3 rounded-lg border border-stone-500 bg-white p-4 shadow-lg">
      <h3 class="text-lg font-semibold text-stone-900">Report voucher</h3>
      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Reason</span>
        <select v-model="reason" :class="controlClass" aria-label="Report reason">
          <option v-for="item in reasons" :key="item" :value="item">{{ item }}</option>
        </select>
      </label>
      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Details (optional)</span>
        <textarea
          v-model="details"
          :class="controlClass"
          rows="3"
          maxlength="500"
          placeholder="Add extra context"
          aria-label="Additional details"
        />
      </label>
      <div class="flex flex-wrap gap-2">
        <UButton type="button" color="neutral" variant="soft" @click="emit('close')">Cancel</UButton>
        <UButton type="button" color="primary" :loading="loading" :disabled="loading" @click="submitReport">
          {{ loading ? 'Submitting...' : 'Submit report' }}
        </UButton>
      </div>
    </div>
  </div>
</template>
