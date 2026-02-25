import { createRouter, createWebHashHistory } from 'vue-router'
import Browse from '@/views/Browse.vue'
import VoucherDetail from '@/views/VoucherDetail.vue'
import Submit from '@/views/Submit.vue'
import MyVouchers from '@/views/MyVouchers.vue'
import Leaderboard from '@/views/Leaderboard.vue'
import Profile from '@/views/Profile.vue'
import NotFound from '@/views/NotFound.vue'
import { useAuth } from '@/composables/useAuth'
import { useLoginPrompt } from '@/composables/useLoginPrompt'

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', redirect: '/browse' },
    { path: '/browse', name: 'browse', component: Browse },
    { path: '/voucher/:id', name: 'voucher-detail', component: VoucherDetail },
    { path: '/submit', name: 'submit', component: Submit, meta: { requiresAuth: true } },
    { path: '/my-vouchers', name: 'my-vouchers', component: MyVouchers, meta: { requiresAuth: true } },
    { path: '/leaderboard', name: 'leaderboard', component: Leaderboard },
    { path: '/profile', name: 'profile', component: Profile, meta: { requiresAuth: true } },
    { path: '/:pathMatch(.*)*', name: 'not-found', component: NotFound }
  ]
})

router.beforeEach(async (to) => {
  const auth = useAuth()
  const prompt = useLoginPrompt()
  await auth.initializeAuth()

  if (to.meta.requiresAuth && !auth.isAuthenticated.value) {
    prompt.openLoginPrompt('Please sign in to access this page.')
    return {
      name: 'browse',
      query: { redirect: to.fullPath }
    }
  }

  return true
})

export default router
