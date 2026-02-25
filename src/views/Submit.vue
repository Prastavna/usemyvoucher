<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { recognize } from 'tesseract.js'
import { useAuth } from '@/composables/useAuth'
import { DEFAULT_VOUCHER_CATEGORIES } from '@/constants/categories'
import { useLoginPrompt } from '@/composables/useLoginPrompt'
import { useToast } from '@/composables/useToast'
import supabase from '@/lib/supabase'

const router = useRouter()
const auth = useAuth()
const prompt = useLoginPrompt()
const toast = useToast()

const loading = ref(false)
const extracting = ref(false)
const extractionProgress = ref(0)
const extractedText = ref('')
const selectedImageName = ref('')

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

type ExtractedVoucherFields = Partial<typeof form>

function toIsoDate(year: number, month: number, day: number) {
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return ''
  }

  const candidate = new Date(year, month - 1, day)
  if (
    Number.isNaN(candidate.getTime()) ||
    candidate.getFullYear() !== year ||
    candidate.getMonth() !== month - 1 ||
    candidate.getDate() !== day
  ) {
    return ''
  }

  return `${year.toString().padStart(4, '0')}-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`
}

function normalizeYear(rawYear: string) {
  const parsedYear = Number(rawYear)
  if (rawYear.length === 2) {
    return parsedYear < 50 ? 2000 + parsedYear : 1900 + parsedYear
  }

  return parsedYear
}

function parseDateCandidate(value: string) {
  const trimmed = value.trim()
  if (!trimmed) {
    return ''
  }

  const isoMatch = trimmed.match(/(\d{4})[\/.\-](\d{1,2})[\/.\-](\d{1,2})/)
  if (isoMatch) {
    return toIsoDate(Number(isoMatch[1]), Number(isoMatch[2]), Number(isoMatch[3]))
  }

  const numericMatch = trimmed.match(/(\d{1,2})[\/.\-](\d{1,2})[\/.\-](\d{2,4})/)
  if (numericMatch) {
    const first = Number(numericMatch[1])
    const second = Number(numericMatch[2])
    const year = normalizeYear(numericMatch[3] ?? '')
    const month = first > 12 ? second : first
    const day = first > 12 ? first : second

    return toIsoDate(year, month, day)
  }

  const monthMap: Record<string, number> = {
    jan: 1,
    feb: 2,
    mar: 3,
    apr: 4,
    may: 5,
    jun: 6,
    jul: 7,
    aug: 8,
    sep: 9,
    oct: 10,
    nov: 11,
    dec: 12
  }

  const dayMonthYearMatch = trimmed.match(/(\d{1,2})\s+([A-Za-z]{3,9})\s*,?\s*(\d{2,4})/)
  if (dayMonthYearMatch) {
    const monthToken = dayMonthYearMatch[2] ?? ''
    const yearToken = dayMonthYearMatch[3] ?? ''
    const dayToken = dayMonthYearMatch[1] ?? ''
    const month = monthMap[monthToken.slice(0, 3).toLowerCase()]
    if (month) {
      return toIsoDate(normalizeYear(yearToken), month, Number(dayToken))
    }
  }

  const monthDayYearMatch = trimmed.match(/([A-Za-z]{3,9})\s+(\d{1,2}),?\s*(\d{2,4})/)
  if (monthDayYearMatch) {
    const monthToken = monthDayYearMatch[1] ?? ''
    const dayToken = monthDayYearMatch[2] ?? ''
    const yearToken = monthDayYearMatch[3] ?? ''
    const month = monthMap[monthToken.slice(0, 3).toLowerCase()]
    if (month) {
      return toIsoDate(normalizeYear(yearToken), month, Number(dayToken))
    }
  }

  return ''
}

function extractDate(text: string) {
  const expiryLineMatch = text.match(/(?:expiry|expires?|valid\s*until)\s*[:\-]?\s*([^\n]+)/i)
  if (expiryLineMatch?.[1]) {
    const parsedFromLine = parseDateCandidate(expiryLineMatch[1])
    if (parsedFromLine) {
      return parsedFromLine
    }
  }

  return parseDateCandidate(text)
}

function findFirstMatch(text: string, patterns: RegExp[]) {
  for (const pattern of patterns) {
    const match = text.match(pattern)
    if (match?.[1]) {
      return match[1].trim()
    }
  }

  return ''
}

function pickCategory(text: string) {
  const normalizedText = text.toLowerCase()

  for (const category of DEFAULT_VOUCHER_CATEGORIES) {
    const keywords = category
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((value) => value.length > 3 && value !== 'others')

    if (keywords.some((keyword) => normalizedText.includes(keyword))) {
      return category
    }
  }

  return ''
}

function extractVoucherFields(rawText: string): ExtractedVoucherFields {
  const sanitizedText = rawText.replace(/\r/g, '')
  const lines = sanitizedText
    .split('\n')
    .map((line) => line.replace(/\s+/g, ' ').trim())
    .filter(Boolean)

  const merchantFromLabel = findFirstMatch(sanitizedText, [
    /(?:merchant|store|shop|vendor|brand)\s*[:\-]\s*(.+)/i,
    /(?:from)\s*[:\-]\s*(.+)/i
  ])

  const merchantFallback = lines.find(
    (line) =>
      line.length >= 3 &&
      line.length <= 60 &&
      !/(voucher|coupon|promo|discount|expiry|expires|valid|code|offer|receipt)/i.test(line)
  )

  const codeFromLabel = findFirstMatch(sanitizedText, [
    /(?:voucher|coupon|promo|discount)\s*code\s*[:#\-]?\s*([A-Za-z0-9][A-Za-z0-9\-_]{3,})/i,
    /\bcode\s*[:#\-]?\s*([A-Za-z0-9][A-Za-z0-9\-_]{3,})/i
  ])

  const codeFallbackMatches = sanitizedText.match(/\b[A-Z0-9][A-Z0-9\-_]{5,20}\b/g) ?? []
  const codeFallback = codeFallbackMatches.find((candidate) => {
    if (/^\d+$/.test(candidate)) {
      return false
    }

    if (/\d{4}[\-\/.]\d{1,2}[\-\/.]\d{1,2}/.test(candidate)) {
      return false
    }

    return true
  })

  const discountFromLabel = findFirstMatch(sanitizedText, [
    /(?:discount|offer|deal|save(?:\s*up\s*to)?)\s*[:\-]\s*(.+)/i
  ])

  const discountFallback =
    sanitizedText.match(/\b\d{1,3}\s?%\s*(?:off|discount)?\b/i)?.[0] ??
    sanitizedText.match(/(?:\$|₹|€|£)\s?\d+(?:\.\d{1,2})?\s*(?:off|discount)?\b/i)?.[0] ??
    ''

  const maxUsesMatch = sanitizedText.match(/(?:max(?:imum)?\s*uses?|uses?)\s*[:\-]?\s*(\d{1,3})/i)
  const maxUses = maxUsesMatch ? Number(maxUsesMatch[1]) : null

  const description = findFirstMatch(sanitizedText, [
    /(?:description|details|terms?)\s*[:\-]\s*(.+)/i
  ])

  const extracted: ExtractedVoucherFields = {
    merchant_name: merchantFromLabel || merchantFallback || '',
    voucher_code: (codeFromLabel || codeFallback || '').toUpperCase(),
    discount_value: discountFromLabel || discountFallback,
    expiry_date: extractDate(sanitizedText),
    category: pickCategory(sanitizedText),
    description,
    max_uses: maxUses && maxUses > 0 ? maxUses : undefined
  }

  return extracted
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
        <pre class="mt-2 max-h-32 overflow-auto whitespace-pre-wrap text-xs text-stone-700">{{ extractedText }}</pre>
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
