/// <reference lib="webworker" />
import { clientsClaim } from 'workbox-core'
import { cleanupOutdatedCaches, precacheAndRoute } from 'workbox-precaching'

declare let self: ServiceWorkerGlobalScope

type PushPayload = {
  title?: string
  body?: string
  path?: string
}

self.skipWaiting()
clientsClaim()
precacheAndRoute(self.__WB_MANIFEST)
cleanupOutdatedCaches()

self.addEventListener('push', (event) => {
  const payload = readPayload(event)
  event.waitUntil(
    self.registration.showNotification(payload.title || 'Coloc', {
      body: payload.body,
      icon: '/apple-touch-icon.png',
      data: { path: payload.path || '/' },
    }),
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const path = notificationPath(event.notification)
  event.waitUntil(openPath(path))
})

function readPayload(event: PushEvent): PushPayload {
  if (!event.data) return {}
  try {
    return event.data.json() as PushPayload
  } catch {
    return { body: event.data.text() }
  }
}

function notificationPath(notification: Notification) {
  const data = notification.data as { path?: string } | undefined
  return data?.path && data.path.startsWith('/') ? data.path : '/'
}

async function openPath(path: string) {
  const url = new URL(path, self.location.origin).href
  const windowClients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true })
  for (const client of windowClients) {
    if (new URL(client.url).origin !== self.location.origin) continue
    if ('navigate' in client) await (client as WindowClient).navigate(url)
    await client.focus()
    return
  }
  await self.clients.openWindow(url)
}
