import { registerSW } from 'virtual:pwa-register'
import { api } from './api'

export type PushConfig = {
  public_key: string | null
  subscribed: boolean
}

let registrationPromise: Promise<ServiceWorkerRegistration> | null = null

export function ensureServiceWorker() {
  registrationPromise ??= startServiceWorker()
  return registrationPromise
}

function startServiceWorker() {
  registerSW({ immediate: true })
  return navigator.serviceWorker.ready
}

export function pushSupported() {
  return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window
}

export function iosBrowser() {
  return /iphone|ipad|ipod/i.test(navigator.userAgent)
}

export function installedApp() {
  const standalone = (navigator as Navigator & { standalone?: boolean }).standalone === true
  return window.matchMedia('(display-mode: standalone)').matches || standalone
}

export async function fetchPushConfig(endpoint?: string) {
  const params = endpoint ? `?${new URLSearchParams({ endpoint })}` : ''
  return api<PushConfig>(`/api/push_subscription${params}`)
}

export async function savePushSubscription(subscription: PushSubscription) {
  const json = subscription.toJSON()
  await api<void>('/api/push_subscription', {
    method: 'PUT',
    body: JSON.stringify({
      endpoint: json.endpoint,
      p256dh: json.keys?.p256dh,
      auth: json.keys?.auth,
    }),
  })
}

export async function deletePushSubscription(endpoint: string) {
  await api<void>('/api/push_subscription', {
    method: 'DELETE',
    body: JSON.stringify({ endpoint }),
  })
}

export function applicationServerKey(publicKey: string) {
  const padding = '='.repeat((4 - (publicKey.length % 4)) % 4)
  const normalized = (publicKey + padding).replace(/-/g, '+').replace(/_/g, '/')
  const raw = atob(normalized)
  const output = new Uint8Array(raw.length)
  for (let index = 0; index < raw.length; index += 1) output[index] = raw.charCodeAt(index)
  return output
}
