import { DEFAULT_VOUCHER_CATEGORIES } from '@/constants/categories'

export type ExtractedVoucherFields = {
  merchant_name?: string
  voucher_code?: string
  description?: string
  discount_value?: string
  expiry_date?: string
  category?: string
  max_uses?: number
}

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

export function getExtractedTextLines(rawText: string) {
  return rawText
    .replace(/\r/g, '')
    .split('\n')
    .map((line) => line.replace(/\s+/g, ' ').trim())
    .filter(Boolean)
}

export function extractVoucherFields(rawText: string): ExtractedVoucherFields {
  const sanitizedText = rawText.replace(/\r/g, '')
  const lines = getExtractedTextLines(sanitizedText)

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

  return {
    merchant_name: merchantFromLabel || merchantFallback || '',
    voucher_code: (codeFromLabel || codeFallback || '').toUpperCase(),
    discount_value: discountFromLabel || discountFallback,
    expiry_date: extractDate(sanitizedText),
    category: pickCategory(sanitizedText),
    description,
    max_uses: maxUses && maxUses > 0 ? maxUses : undefined
  }
}
