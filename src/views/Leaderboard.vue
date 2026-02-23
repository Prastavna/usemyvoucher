<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useAuth } from '@/composables/useAuth'
import supabase from '@/lib/supabase'
import type { Tables } from '@/types/supabase-generated'

const auth = useAuth()

const loading = ref(true)
const errorMessage = ref('')
const users = ref<Tables<'profiles'>[]>([])

const rankedUsers = computed(() => users.value.map((user, index) => ({ rank: index + 1, user })))

async function loadLeaderboard() {
  loading.value = true
  errorMessage.value = ''

  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .order('points', { ascending: false, nullsFirst: false })
    .limit(100)

  loading.value = false

  if (error) {
    errorMessage.value = error.message
    return
  }

  users.value = data
}

function displayName(user: Tables<'profiles'>) {
  return user.display_name || user.email
}

function isCurrentUser(id: string) {
  return auth.user.value?.id === id
}

onMounted(loadLeaderboard)
</script>

<template>
  <section class="page-shell">
    <div class="page-head">
      <h1>Leaderboard</h1>
      <p>Top contributors ranked by points.</p>
    </div>

    <p v-if="loading">Loading leaderboard...</p>
    <p v-else-if="errorMessage" class="error-state">Failed to load leaderboard: {{ errorMessage }}</p>

    <div v-else class="leaderboard-table-wrap">
      <table class="leaderboard-table">
        <thead>
          <tr>
            <th>Rank</th>
            <th>User</th>
            <th>Points</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="entry in rankedUsers" :key="entry.user.id" :class="{ highlight: isCurrentUser(entry.user.id) }">
            <td>#{{ entry.rank }}</td>
            <td class="user-cell">
              <img v-if="entry.user.avatar_url" :src="entry.user.avatar_url" alt="Avatar" class="avatar" />
              <span>{{ displayName(entry.user) }}</span>
            </td>
            <td>{{ entry.user.points || 0 }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
