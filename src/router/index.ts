import { createRouter, createWebHistory } from 'vue-router'
import Landing from '@/views/Landing.vue'
import Browse from '@/views/Browse.vue'
import VoucherDetail from '@/views/VoucherDetail.vue'
import Submit from '@/views/Submit.vue'
import MyVouchers from '@/views/MyVouchers.vue'
import Leaderboard from '@/views/Leaderboard.vue'
import Profile from '@/views/Profile.vue'
import NotFound from '@/views/NotFound.vue'
import { useAuth } from '@/composables/useAuth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'landing', component: Landing },
    { path: '/browse', name: 'browse', component: Browse, meta: { requiresAuth: true } },
    { path: '/voucher/:id', name: 'voucher-detail', component: VoucherDetail, meta: { requiresAuth: true } },
    { path: '/submit', name: 'submit', component: Submit, meta: { requiresAuth: true } },
    { path: '/my-vouchers', name: 'my-vouchers', component: MyVouchers, meta: { requiresAuth: true } },
    { path: '/leaderboard', name: 'leaderboard', component: Leaderboard, meta: { requiresAuth: true } },
    { path: '/profile', name: 'profile', component: Profile, meta: { requiresAuth: true } },
    { path: '/:pathMatch(.*)*', name: 'not-found', component: NotFound, meta: { requiresAuth: true } }
  ]
})

router.beforeEach(async (to) => {
  const auth = useAuth()
  await auth.initializeAuth()

  if (to.meta.requiresAuth && !auth.isAuthenticated.value) {
    return {
      name: 'landing',
      query: { redirect: to.fullPath }
    }
  }

  if (to.name === 'landing' && auth.isAuthenticated.value) {
    return { name: 'browse' }
  }

  return true
})

export default router
