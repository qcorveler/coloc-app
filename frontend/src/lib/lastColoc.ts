import { listColocs } from './colocs'

const COLOC_PATH = /^\/colocs\/(\d+)(\/planning)?$/

function storageKey(userId: number) {
  return `last-coloc-path:${userId}`
}

export function rememberColocPath(userId: number, path: string) {
  if (!COLOC_PATH.test(path)) return
  try {
    localStorage.setItem(storageKey(userId), path)
  } catch {
    // Le navigateur peut refuser le stockage (mode privé).
  }
}

export function readColocPath(userId: number) {
  try {
    const value = localStorage.getItem(storageKey(userId))
    if (!value || !COLOC_PATH.test(value)) return null
    return value
  } catch {
    return null
  }
}

export function resolveColocEntry(userId: number, colocs: { id: number }[]) {
  if (colocs.length === 0) return null
  const saved = readColocPath(userId)
  const savedId = saved ? Number(COLOC_PATH.exec(saved)?.[1]) : null
  if (saved && savedId !== null && colocs.some((coloc) => coloc.id === savedId)) return saved
  return `/colocs/${colocs[0].id}`
}

export async function entryPath(userId: number) {
  const colocs = await listColocs()
  return resolveColocEntry(userId, colocs) ?? '/'
}
