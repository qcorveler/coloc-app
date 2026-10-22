import { createRouter, createWebHistory } from 'vue-router'
import { useAuth } from '../composables/useAuth'

declare module 'vue-router' {
  interface RouteMeta {
    requiresAuth?: boolean
    guest?: boolean
  }
}

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      component: () => import('../views/HomeView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/login',
      component: () => import('../views/LoginView.vue'),
      meta: { guest: true },
    },
    {
      path: '/signup',
      component: () => import('../views/SignupView.vue'),
      meta: { guest: true },
    },
  ],
})

router.beforeEach(async (to) => {
  const { ensureLoaded, user } = useAuth()
  await ensureLoaded()

  if (to.meta.requiresAuth && !user.value) {
    return { path: '/login' }
  }

  if (to.meta.guest && user.value) {
    return { path: '/' }
  }
})
