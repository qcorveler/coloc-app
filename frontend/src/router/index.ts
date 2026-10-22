import { createRouter, createWebHistory } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { internalPath } from '../lib/redirect'

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
      path: '/colocs/nouvelle',
      component: () => import('../views/NewColocView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/colocs/:id',
      component: () => import('../views/ColocView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/colocs/:id/modifier',
      component: () => import('../views/EditColocView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/rejoindre/:token',
      component: () => import('../views/JoinView.vue'),
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
    return { path: '/login', query: { redirect: to.fullPath } }
  }

  if (to.meta.guest && user.value) {
    return internalPath(to.query.redirect) ?? '/'
  }
})
