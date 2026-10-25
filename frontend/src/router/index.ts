import { createRouter, createWebHistory } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { entryPath, rememberColocPath } from '../lib/lastColoc'
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
      component: () => import('../layouts/PlainLayout.vue'),
      children: [
        {
          path: '',
          component: () => import('../views/HomeView.vue'),
          meta: { requiresAuth: true },
        },
        {
          path: 'login',
          component: () => import('../views/LoginView.vue'),
          meta: { guest: true },
        },
        {
          path: 'signup',
          component: () => import('../views/SignupView.vue'),
          meta: { guest: true },
        },
        {
          path: 'colocs/nouvelle',
          component: () => import('../views/NewColocView.vue'),
          meta: { requiresAuth: true },
        },
        {
          path: 'colocs/:id/modifier',
          component: () => import('../views/EditColocView.vue'),
          meta: { requiresAuth: true },
        },
        {
          path: 'rejoindre/:token',
          component: () => import('../views/JoinView.vue'),
          meta: { requiresAuth: true },
        },
      ],
    },
    {
      path: '/colocs/:id',
      component: () => import('../layouts/ColocShell.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'coloc-home',
          component: () => import('../views/ColocView.vue'),
        },
        {
          path: 'planning',
          name: 'coloc-planning',
          component: () => import('../views/PlanningView.vue'),
        },
      ],
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
    const redirect = internalPath(to.query.redirect)
    if (redirect) return redirect
    try {
      return await entryPath(user.value.id)
    } catch {
      return '/'
    }
  }
})

router.afterEach((to) => {
  const { user } = useAuth()
  if (!user.value) return
  if (to.name === 'coloc-home' || to.name === 'coloc-planning') {
    rememberColocPath(user.value.id, to.path)
  }
})
