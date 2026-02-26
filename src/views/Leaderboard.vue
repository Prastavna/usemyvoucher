<script setup lang="ts">
import { computed, onActivated, onMounted, ref } from 'vue'
import { useAuth } from '@/composables/useAuth'
import supabase from '@/lib/supabase'

type LeaderboardUser = {
  id: string
  display_name: string | null
  avatar_url: string | null
  points: number | null
}

const auth = useAuth()

const loading = ref(true)
const errorMessage = ref('')
const users = ref<LeaderboardUser[]>([])

const rankedUsers = computed(() => {
  const withPoints = users.value.filter((user) => (user.points || 0) > 0)
  return withPoints.map((user, index) => ({ rank: index + 1, user }))
})

async function loadLeaderboard() {
  loading.value = true
  errorMessage.value = ''

  const { data, error } = await (supabase as typeof supabase & {
    rpc: (fn: string, args?: Record<string, unknown>) => Promise<{ data: unknown; error: { message: string } | null }>
  }).rpc('get_public_leaderboard', {
    limit_count: 100
  })

  loading.value = false

  if (error) {
    errorMessage.value = error.message
    return
  }

  users.value = (data || []) as LeaderboardUser[]
}

function displayName(user: LeaderboardUser) {
  return user.display_name || 'Community member'
}

function isCurrentUser(id: string) {
  return auth.user.value?.id === id
}

onMounted(loadLeaderboard)
onActivated(loadLeaderboard)
</script>

<template>
  <section class="mx-auto max-w-6xl space-y-4">
    <div class="space-y-1">
      <h1 class="text-3xl font-bold tracking-tight text-stone-900">Leaderboard</h1>
      <p class="text-stone-600">Top contributors ranked by total points.</p>
    </div>

    <article class="space-y-2 rounded-md border border-stone-400 bg-amber-50 px-4 py-3">
      <h2 class="text-base font-semibold text-stone-900">How points work</h2>
      <ul class="list-disc space-y-1 pl-5 text-sm text-stone-700">
        <li>Submit a voucher: <strong>+10</strong> points</li>
        <li>Use someone else's voucher: <strong>+5</strong> points</li>
        <li>Your voucher used by someone else: <strong>+2</strong> points</li>
        <li>Mark your own voucher as used: <strong>-10</strong> points and voucher is removed from active listings</li>
      </ul>
      <p class="text-xs text-stone-600">Ranking is sorted by total points in descending order.</p>
    </article>

    <p v-if="loading" class="text-stone-600">Loading leaderboard...</p>
    <p v-else-if="errorMessage" class="rounded-md border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-800">
      Failed to load leaderboard: {{ errorMessage }}
    </p>

    <div v-else class="overflow-x-auto">
      <table class="w-full overflow-hidden rounded-md border border-stone-500 bg-white">
        <thead>
          <tr>
            <th class="border-b border-stone-200 px-3 py-2 text-left text-sm font-semibold text-stone-700">Rank</th>
            <th class="border-b border-stone-200 px-3 py-2 text-left text-sm font-semibold text-stone-700">User</th>
            <th class="border-b border-stone-200 px-3 py-2 text-left text-sm font-semibold text-stone-700">Points</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="entry in rankedUsers"
            :key="entry.user.id"
            :class="{ 'bg-teal-50': isCurrentUser(entry.user.id) }"
          >
            <td class="border-b border-stone-200 px-3 py-2 text-sm text-stone-700">#{{ entry.rank }}</td>
            <td class="border-b border-stone-200 px-3 py-2 text-sm text-stone-700">
              <div class="flex items-center gap-2">
                <img v-if="entry.user.avatar_url" :src="entry.user.avatar_url" alt="Avatar" class="size-8 rounded-full object-cover" />
                <span>{{ displayName(entry.user) }}</span>
              </div>
            </td>
            <td class="border-b border-stone-200 px-3 py-2 text-sm font-semibold text-stone-900">{{ entry.user.points || 0 }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
