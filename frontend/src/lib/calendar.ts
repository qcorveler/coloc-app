import { api } from './api'
import { addDays } from './dates'

export type Recurrence = 'none' | 'daily' | 'weekly' | 'monthly'

export type CalendarEvent = {
  id: number
  occurrence_on: string
  title: string
  notes: string | null
  all_day: boolean
  starts_at: string
  ends_at: string
  recurring: boolean
  recurrence: Recurrence
  weekdays: number[]
  until_on: string | null
  series_starts_at: string
  series_ends_at: string
  series_title: string
  series_notes: string | null
  series_all_day: boolean
}

export type RotationWeek = {
  id: number
  title: string
  starts_on: string
  ends_on: string
  rule_starts_on: string
  rule_ends_on: string | null
  turn_days: number
  offset_days: number
  member_ids: number[]
  user: {
    id: number
    first_name: string
    last_name: string
  }
}

export type CalendarPayload = {
  events: CalendarEvent[]
  rotations: RotationWeek[]
}

export type EventInput = {
  title: string
  notes: string
  all_day: boolean
  starts_at: string
  ends_at: string
  recurrence: Recurrence
  weekdays: number[]
  until_on: string | null
}

export type RotationInput = {
  title: string
  starts_on: string
  ends_on: null
  turn_days: number
  offset_days: number
  member_ids: number[]
}

const MEMBER_COLORS = ['#7c5cbf', '#0f8a7e', '#d06a2b', '#2f6f9f', '#b4234e', '#5c7f22']

export function memberColor(userId: number) {
  return MEMBER_COLORS[Math.abs(userId) % MEMBER_COLORS.length]
}

export function overlapsDay(startsAt: string, endsAt: string, day: string) {
  const dayStart = `${day}T00:00`
  const dayEnd = `${addDays(day, 1)}T00:00`
  return startsAt.slice(0, 16) < dayEnd && endsAt.slice(0, 16) > dayStart
}

export function intervalOnDay(startsAt: string, endsAt: string, day: string) {
  const dayStart = `${day}T00:00`
  const dayEnd = `${addDays(day, 1)}T00:00`
  const startKey = startsAt.slice(0, 16)
  const endKey = endsAt.slice(0, 16)
  if (!(startKey < dayEnd && endKey > dayStart)) return null

  const start = startKey <= dayStart ? 0 : clockMinutes(startsAt)
  const end = endKey >= dayEnd ? 24 * 60 : clockMinutes(endsAt)
  if (end <= start) return null
  return { start, end }
}

export async function fetchCalendar(colocId: number | string, from: string, to: string) {
  const params = new URLSearchParams({ from, to })
  return api<CalendarPayload>(`/api/colocs/${colocId}/calendar?${params}`)
}

export async function saveEvent(
  colocId: number | string,
  eventId: number | null,
  fields: EventInput,
  occurrence?: string,
) {
  const path = eventId === null ? `/api/colocs/${colocId}/events` : `/api/colocs/${colocId}/events/${eventId}`
  const method = eventId === null ? 'POST' : 'PATCH'
  const query = occurrence ? `?occurrence=${encodeURIComponent(occurrence)}` : ''
  await api(`${path}${query}`, { method, body: JSON.stringify(fields) })
}

export async function deleteEvent(colocId: number | string, eventId: number, occurrence?: string) {
  const query = occurrence ? `?occurrence=${encodeURIComponent(occurrence)}` : ''
  await api<void>(`/api/colocs/${colocId}/events/${eventId}${query}`, { method: 'DELETE' })
}

export async function saveRotation(colocId: number | string, rotationId: number | null, fields: RotationInput) {
  const path = rotationId === null
    ? `/api/colocs/${colocId}/rotations`
    : `/api/colocs/${colocId}/rotations/${rotationId}`
  const method = rotationId === null ? 'POST' : 'PATCH'
  await api(path, { method, body: JSON.stringify(fields) })
}

export async function deleteRotation(colocId: number | string, rotationId: number) {
  await api<void>(`/api/colocs/${colocId}/rotations/${rotationId}`, { method: 'DELETE' })
}

function clockMinutes(iso: string) {
  const [hour, minute] = iso.slice(11, 16).split(':').map(Number)
  return hour * 60 + minute
}
