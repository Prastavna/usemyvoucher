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
  <div v-if="open" class="modal-backdrop" role="dialog" aria-modal="true" aria-label="Report voucher dialog">
    <div class="modal-panel">
      <h3>Report voucher</h3>
      <label class="field">
        <span>Reason</span>
        <select v-model="reason" aria-label="Report reason">
          <option v-for="item in reasons" :key="item" :value="item">{{ item }}</option>
        </select>
      </label>
      <label class="field">
        <span>Details (optional)</span>
        <textarea
          v-model="details"
          rows="3"
          maxlength="500"
          placeholder="Add extra context"
          aria-label="Additional details"
        />
      </label>
      <div class="actions">
        <button type="button" class="secondary" @click="emit('close')">Cancel</button>
        <button type="button" class="primary" @click="submitReport" :disabled="loading">
          {{ loading ? 'Submitting...' : 'Submit report' }}
        </button>
      </div>
    </div>
  </div>
</template>
