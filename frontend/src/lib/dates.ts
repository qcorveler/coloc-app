export function addDays(iso: string, days: number) {
  const [year, month, day] = iso.split('-').map(Number)
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10)
}

export function mondayOf(iso: string) {
  const [year, month, day] = iso.split('-').map(Number)
  const date = new Date(Date.UTC(year, month - 1, day))
  const weekday = date.getUTCDay()
  const delta = weekday === 0 ? -6 : 1 - weekday
  date.setUTCDate(date.getUTCDate() + delta)
  return date.toISOString().slice(0, 10)
}

export function isoWeekday(iso: string) {
  const [year, month, day] = iso.split('-').map(Number)
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay()
  return weekday === 0 ? 7 : weekday
}

export function todayIso() {
  const now = new Date()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${now.getFullYear()}-${month}-${day}`
}

export function addMonths(iso: string, count: number) {
  const [year, month, day] = iso.split('-').map(Number)
  const shifted = new Date(Date.UTC(year, month - 1 + count, 1))
  const last = new Date(Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth() + 1, 0)).getUTCDate()
  return new Date(Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), Math.min(day, last)))
    .toISOString()
    .slice(0, 10)
}

export function monthGrid(cursor: string) {
  const start = mondayOf(`${cursor.slice(0, 7)}-01`)
  return Array.from({ length: 42 }, (_, index) => addDays(start, index))
}

export function weekDates(cursor: string) {
  const start = mondayOf(cursor)
  return Array.from({ length: 7 }, (_, index) => addDays(start, index))
}

export function parseLocal(iso: string) {
  const [year, month, day] = iso.split('-').map(Number)
  return new Date(year, month - 1, day)
}

export function formatMonth(iso: string) {
  return new Intl.DateTimeFormat('fr-FR', { month: 'long', year: 'numeric' }).format(parseLocal(iso))
}

export function formatDay(iso: string) {
  return new Intl.DateTimeFormat('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' }).format(parseLocal(iso))
}

export function formatShort(iso: string) {
  return new Intl.DateTimeFormat('fr-FR', { weekday: 'short', day: 'numeric' }).format(parseLocal(iso))
}

export function formatWeek(cursor: string) {
  const days = weekDates(cursor)
  const start = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' }).format(parseLocal(days[0]))
  const end = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' }).format(parseLocal(days[6]))
  return `${start} – ${end}`
}

export function parisDate(iso: string) {
  return iso.slice(0, 10)
}

export function clock(iso: string) {
  return iso.slice(11, 16)
}

export function inclusiveEndDate(endsAt: string) {
  const day = parisDate(endsAt)
  return endsAt.slice(11, 16) === '00:00' ? addDays(day, -1) : day
}

export function dayDelta(from: string, to: string) {
  const [fromYear, fromMonth, fromDay] = from.split('-').map(Number)
  const [toYear, toMonth, toDay] = to.split('-').map(Number)
  const start = Date.UTC(fromYear, fromMonth - 1, fromDay)
  const end = Date.UTC(toYear, toMonth - 1, toDay)
  return Math.round((end - start) / 86_400_000)
}

export function alignToWeekday(date: string, weekdays: number[]) {
  if (weekdays.length === 0) return date
  const wanted = new Set(weekdays)
  let cursor = date
  for (let step = 0; step < 7; step += 1) {
    if (wanted.has(isoWeekday(cursor))) return cursor
    cursor = addDays(cursor, 1)
  }
  return date
}

export const WEEKDAY_OPTIONS = [
  { value: 1, label: 'Lun' },
  { value: 2, label: 'Mar' },
  { value: 3, label: 'Mer' },
  { value: 4, label: 'Jeu' },
  { value: 5, label: 'Ven' },
  { value: 6, label: 'Sam' },
  { value: 7, label: 'Dim' },
]
