<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { recognize } from 'tesseract.js'
import { useAuth } from '@/composables/useAuth'
import { DEFAULT_VOUCHER_CATEGORIES } from '@/constants/categories'
import { useLoginPrompt } from '@/composables/useLoginPrompt'
import { useToast } from '@/composables/useToast'
import supabase from '@/lib/supabase'
import { copyToClipboard } from '@/utils/copy'
import { extractVoucherFields, getExtractedTextLines, type ExtractedVoucherFields } from '@/utils/voucherExtraction'

const router = useRouter()
const auth = useAuth()
const prompt = useLoginPrompt()
const toast = useToast()

const loading = ref(false)
const extracting = ref(false)
const extractionProgress = ref(0)
const extractedText = ref('')
const selectedImageName = ref('')
const copiedLineIndex = ref<number | null>(null)
const copiedLineResetTimer = ref<number | null>(null)

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

const extractedLines = computed(() => getExtractedTextLines(extractedText.value))

async function copyExtractedLine(line: string, index: number) {
  const copied = await copyToClipboard(line)
  if (!copied) {
    toast.error('Failed to copy line to clipboard.')
    return
  }

  copiedLineIndex.value = index
  toast.success('Line copied to clipboard.')

  if (copiedLineResetTimer.value !== null) {
    window.clearTimeout(copiedLineResetTimer.value)
  }

  copiedLineResetTimer.value = window.setTimeout(() => {
    copiedLineIndex.value = null
  }, 1500)
}

function applyExtractedFields(extracted: ExtractedVoucherFields) {
  if (extracted.merchant_name) {
    form.merchant_name = extracted.merchant_name
  }

  if (extracted.voucher_code) {
    form.voucher_code = extracted.voucher_code
  }

  if (extracted.description) {
    form.description = extracted.description
  }

  if (extracted.discount_value) {
    form.discount_value = extracted.discount_value
  }

  if (extracted.expiry_date) {
    form.expiry_date = extracted.expiry_date
  }

  if (extracted.category) {
    form.category = extracted.category
  }

  if (typeof extracted.max_uses === 'number' && extracted.max_uses >= 1) {
    form.max_uses = extracted.max_uses
  }
}

async function extractFromImage(event: Event) {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]

  if (!file) {
    return
  }

  extracting.value = true
  extractionProgress.value = 0
  selectedImageName.value = file.name
  extractedText.value = ''
  copiedLineIndex.value = null

  try {
    const result = await recognize(file, 'eng', {
      logger: (message) => {
        if (message.status === 'recognizing text') {
          extractionProgress.value = message.progress
        }
      }
    })

    const text = result.data.text.trim()
    extractedText.value = text

    if (!text) {
      toast.info('No readable text was found in that image.')
      return
    }

    const extracted = extractVoucherFields(text)
    const hasDetectedField = Object.values(extracted).some((value) => {
      if (typeof value === 'number') {
        return true
      }

      return Boolean(value)
    })

    if (!hasDetectedField) {
      toast.info('Text was extracted, but no voucher fields were confidently matched.')
      return
    }

    applyExtractedFields(extracted)
    toast.success('Details extracted and added to the form.')
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Failed to extract text from image'
    toast.error(message)
  } finally {
    extracting.value = false
    extractionProgress.value = 0
    target.value = ''
  }
}

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

    <section class="space-y-2 rounded-md border border-stone-300 bg-white p-4 shadow-sm">
      <h2 class="text-lg font-semibold text-stone-900">Extract from an image</h2>
      <p class="text-sm text-stone-600">Upload a screenshot, coupon card, or receipt. OCR runs locally in your browser.</p>

      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-stone-700">Coupon image</span>
        <input
          type="file"
          accept="image/*"
          :class="controlClass"
          :disabled="extracting"
          @change="extractFromImage"
          aria-label="Upload coupon image"
        />
      </label>

      <p v-if="extracting" class="text-sm text-teal-700">
        Reading image... {{ Math.round(extractionProgress * 100) }}%
      </p>
      <p v-else-if="selectedImageName" class="text-sm text-stone-600">
        Last scanned image: {{ selectedImageName }}
      </p>

      <details v-if="extractedText" class="rounded-md bg-stone-100 p-3">
        <summary class="cursor-pointer text-sm font-medium text-stone-700">View extracted text</summary>
        <div class="mt-2 max-h-48 space-y-1 overflow-auto">
          <div
            v-for="(line, index) in extractedLines"
            :key="`${index}-${line}`"
            class="grid grid-cols-[auto_1fr] items-start gap-2 rounded-sm px-1 py-1"
          >
            <button
              type="button"
              class="rounded border border-stone-300 bg-white px-2 py-0.5 text-[11px] font-medium text-stone-700 transition hover:bg-stone-50"
              :aria-label="`Copy line ${index + 1}`"
              @click="copyExtractedLine(line, index)"
            >
              {{ copiedLineIndex === index ? 'Copied' : 'Copy' }}
            </button>
            <span class="break-words text-xs text-stone-700">{{ line }}</span>
          </div>
        </div>
      </details>
    </section>

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
