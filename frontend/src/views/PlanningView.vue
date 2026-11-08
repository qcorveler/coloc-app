<script setup lang="ts">
import { computed, onUnmounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import DayAgenda from '../components/planning/DayAgenda.vue'
import EventForm from '../components/planning/EventForm.vue'
import MonthGrid from '../components/planning/MonthGrid.vue'
import RotationForm from '../components/planning/RotationForm.vue'
import TimeGrid from '../components/planning/TimeGrid.vue'
import { ApiError } from '../lib/api'
import { confirm } from '../lib/confirm'
import { useAuth } from '../composables/useAuth'
import {
  deleteEvent,
  deleteRotation,
  fetchCalendar,
  subscribeEvent,
  unsubscribeEvent,
  type CalendarEvent,
  type CalendarPayload,
  type RotationWeek,
} from '../lib/calendar'
import { fetchColoc, type Coloc } from '../lib/colocs'
import {
  addDays,
  addMonths,
  clock,
  formatDay,
  formatMonth,
  formatWeek,
  inclusiveEndDate,
  monthGrid,
  parisDate,
  todayIso,
  weekDates,
} from '../lib/dates'

const route = useRoute()
const { user } = useAuth()
const colocId = computed(() => String(route.params.id))
const coloc = ref<Coloc | null>(null)
const emptyPayload: CalendarPayload = { events: [], rotations: [] }
const payload = ref<CalendarPayload>(emptyPayload)
const shownKey = ref('')
const calendarCache = new Map<string, CalendarPayload>()
let requestId = 0
let activeRequest: AbortController | null = null
const mode = ref<'month' | 'week' | 'day'>('month')
const modeOptions = [
  { label: 'Mois', value: 'month' },
  { label: 'Semaine', value: 'week' },
  { label: 'Jour', value: 'day' },
]
const cursor = ref(todayIso())
const loading = ref(true)
const reminding = ref(false)
const errors = ref<string[]>([])

type Panel =
  | { kind: 'event'; mode: 'create' | 'occurrence' | 'series'; event: CalendarEvent | null }
  | { kind: 'rotation'; rotation: RotationWeek | null }
  | { kind: 'event-detail'; event: CalendarEvent }
  | { kind: 'rotation-detail'; rotation: RotationWeek }

const panel = ref<Panel | null>(null)
const slideClass = ref('')
const addMenu = ref<{ hide: () => void } | null>(null)
let swipe: { x: number; y: number; dx: number; dy: number; horizontal: boolean } | null = null

const range = computed(() => periodRange(cursor.value, mode.value))
const currentKey = computed(() => cacheKey(colocId.value, range.value.from, range.value.to))
const visiblePayload = computed(() => (shownKey.value === currentKey.value ? payload.value : emptyPayload))
const periodReady = computed(() => shownKey.value === currentKey.value)

const heading = computed(() => {
  if (mode.value === 'month') return formatMonth(cursor.value)
  if (mode.value === 'week') return formatWeek(cursor.value)
  return formatDay(cursor.value)
})

const visibleDays = computed(() => {
  if (mode.value === 'month') return monthGrid(cursor.value)
  if (mode.value === 'week') return weekDates(cursor.value)
  return [cursor.value]
})

const formKey = computed(() => {
  const current = panel.value
  if (!current) return ''
  if (current.kind === 'event') {
    return `event-${current.mode}-${current.event?.id ?? 'new'}-${current.event?.occurrence_on ?? ''}`
  }
  if (current.kind === 'rotation') return `rotation-${current.rotation?.id ?? 'new'}`
  return current.kind
})

watch(colocId, loadColoc, { immediate: true })
watch([colocId, () => range.value.from, () => range.value.to], () => {
  void loadCalendar()
}, { immediate: true })

onUnmounted(() => activeRequest?.abort())

async function loadColoc() {
  try {
    coloc.value = await fetchColoc(colocId.value)
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger la coloc']
  }
}

function periodRange(cursorValue: string, period: 'month' | 'week' | 'day') {
  if (period === 'month') {
    const days = monthGrid(cursorValue)
    return { from: days[0], to: days[days.length - 1] }
  }
  if (period === 'week') {
    const days = weekDates(cursorValue)
    return { from: days[0], to: days[6] }
  }
  return { from: cursorValue, to: cursorValue }
}

function cacheKey(id: string, from: string, to: string) {
  return `${id}:${from}:${to}`
}

function shiftedCursor(cursorValue: string, period: 'month' | 'week' | 'day', direction: number) {
  if (period === 'month') return addMonths(cursorValue, direction)
  if (period === 'week') return addDays(cursorValue, direction * 7)
  return addDays(cursorValue, direction)
}

function remember(key: string, data: CalendarPayload) {
  calendarCache.delete(key)
  calendarCache.set(key, data)
  while (calendarCache.size > 18) {
    const oldest = calendarCache.keys().next().value
    if (oldest === undefined) break
    calendarCache.delete(oldest)
  }
}

function showPeriod(key: string, data: CalendarPayload) {
  payload.value = data
  shownKey.value = key
  errors.value = []
  loading.value = false
}

function isAbort(error: unknown) {
  return error instanceof Error && error.name === 'AbortError'
}

async function loadCalendar() {
  const id = colocId.value
  const { from, to } = range.value
  const key = cacheKey(id, from, to)
  const cached = calendarCache.get(key)
  const seq = ++requestId
  activeRequest?.abort()
  activeRequest = null
  if (cached) {
    showPeriod(key, cached)
    void prefetchAround(id)
    return
  }

  const controller = new AbortController()
  activeRequest = controller
  loading.value = true
  errors.value = []
  try {
    const next = await fetchCalendar(id, from, to, controller.signal)
    if (seq !== requestId) return
    remember(key, next)
    showPeriod(key, next)
    void prefetchAround(id)
  } catch (error) {
    if (seq !== requestId || isAbort(error)) return
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger le planning']
  } finally {
    if (seq === requestId) loading.value = false
  }
}

async function reloadCalendar() {
  calendarCache.clear()
  await loadCalendar()
}

async function prefetchAround(id: string) {
  const period = mode.value
  const origin = cursor.value
  await Promise.all([-1, 1].map(async (direction) => {
    if (id !== colocId.value) return
    const nextCursor = shiftedCursor(origin, period, direction)
    const next = periodRange(nextCursor, period)
    const key = cacheKey(id, next.from, next.to)
    if (calendarCache.has(key)) return
    try {
      const data = await fetchCalendar(id, next.from, next.to)
      if (id === colocId.value) remember(key, data)
    } catch {
      // Une période voisine peut échouer sans empêcher celle qui est affichée.
    }
  }))
}

function setMode(value: string | number | null) {
  if (value === 'month' || value === 'week' || value === 'day') mode.value = value
}

function closePanel(open: boolean) {
  if (!open) panel.value = null
}

function shift(direction: number) {
  cursor.value = shiftedCursor(cursor.value, mode.value, direction)
  slideClass.value = ''
  requestAnimationFrame(() => {
    slideClass.value = direction > 0 ? 'slide-next' : 'slide-prev'
  })
}

function swipeTargetIgnored(target: EventTarget | null) {
  if (!(target instanceof Element)) return false
  if (target.closest('.q-dialog, .q-menu, input, textarea, select, .q-field')) return true
  const control = target.closest('button, a, label, .q-btn')
  if (!control) return false
  return !control.closest('.calendar')
}

function onPointerDown(event: PointerEvent) {
  if (event.button !== 0 || swipeTargetIgnored(event.target)) return
  endSwipeListeners()
  swipe = { x: event.clientX, y: event.clientY, dx: 0, dy: 0, horizontal: false }
  window.addEventListener('pointermove', trackPointer, { passive: false })
  window.addEventListener('pointerup', finishPointer)
  window.addEventListener('pointercancel', onPointerCancel)
}

function trackPointer(event: PointerEvent) {
  if (!swipe) return
  swipe.dx = event.clientX - swipe.x
  swipe.dy = event.clientY - swipe.y
  if (!swipe.horizontal && Math.abs(swipe.dx) > 10 && Math.abs(swipe.dx) > Math.abs(swipe.dy)) {
    swipe.horizontal = true
  }
  if (swipe.horizontal && event.cancelable) event.preventDefault()
}

function swipeReady(dx: number, dy: number) {
  return Math.abs(dx) >= 50 && Math.abs(dx) > Math.abs(dy) * 1.5
}

function applySwipe(dx: number) {
  shift(dx < 0 ? 1 : -1)
  const stopClick = (click: Event) => {
    click.preventDefault()
    click.stopPropagation()
    window.removeEventListener('click', stopClick, true)
  }
  window.addEventListener('click', stopClick, true)
}

function endSwipeListeners() {
  swipe = null
  window.removeEventListener('pointermove', trackPointer)
  window.removeEventListener('pointerup', finishPointer)
  window.removeEventListener('pointercancel', onPointerCancel)
}

function finishPointer(event: PointerEvent) {
  if (!swipe) return
  const dx = event.clientX - swipe.x
  const dy = event.clientY - swipe.y
  endSwipeListeners()
  if (swipeReady(dx, dy)) applySwipe(dx)
}

function onPointerCancel() {
  if (!swipe) return
  const { dx, dy } = swipe
  endSwipeListeners()
  if (swipeReady(dx, dy)) applySwipe(dx)
}

function createFromMenu(kind: 'event' | 'rotation') {
  addMenu.value?.hide()
  if (kind === 'event') openCreateEvent()
  else openCreateRotation()
}

onUnmounted(endSwipeListeners)

function openDay(day: string) {
  cursor.value = day
  mode.value = 'day'
}

function openCreateEvent() {
  panel.value = { kind: 'event', mode: 'create', event: null }
}

function openCreateRotation() {
  panel.value = { kind: 'rotation', rotation: null }
}

function openEvent(event: CalendarEvent) {
  panel.value = { kind: 'event-detail', event }
}

function openRotation(rotation: RotationWeek) {
  panel.value = { kind: 'rotation-detail', rotation }
}

function canChooseReminders(current: Panel) {
  if (current.kind !== 'event' || current.mode === 'occurrence') return false
  if (current.mode === 'create') return true
  return current.event?.created_by_id === user.value?.id
}

function editEvent(event: CalendarEvent, editMode: 'occurrence' | 'series') {
  panel.value = { kind: 'event', mode: editMode, event }
}

function editRotation(rotation: RotationWeek) {
  panel.value = { kind: 'rotation', rotation }
}

async function toggleReminder(event: CalendarEvent) {
  reminding.value = true
  try {
    if (event.subscribed) await unsubscribeEvent(colocId.value, event.id)
    else await subscribeEvent(colocId.value, event.id)
    const subscribed = !event.subscribed
    payload.value = {
      ...payload.value,
      events: payload.value.events.map((row) => (row.id === event.id ? { ...row, subscribed } : row)),
    }
    if (panel.value?.kind === 'event-detail' && panel.value.event.id === event.id) {
      panel.value = { kind: 'event-detail', event: { ...panel.value.event, subscribed } }
    }
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de modifier le rappel']
  } finally {
    reminding.value = false
  }
}

async function onSaved() {
  panel.value = null
  await reloadCalendar()
}

async function removeEvent(event: CalendarEvent, occurrence?: string) {
  const message = occurrence
    ? 'Supprimer seulement ce jour-ci ?'
    : event.recurring
      ? 'Supprimer toute la série ?'
      : 'Supprimer cet événement ?'
  if (!(await confirm(message, 'Supprimer', 'negative'))) return
  try {
    await deleteEvent(colocId.value, event.id, occurrence)
    panel.value = null
    await reloadCalendar()
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de supprimer l’événement']
  }
}

async function removeRotation(rotation: RotationWeek) {
  if (!(await confirm('Supprimer ce tour ?', 'Supprimer', 'negative'))) return
  try {
    await deleteRotation(colocId.value, rotation.id)
    panel.value = null
    await reloadCalendar()
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de supprimer le tour']
  }
}

function describeEvent(event: CalendarEvent) {
  if (event.all_day) {
    const start = parisDate(event.starts_at)
    const end = inclusiveEndDate(event.ends_at)
    return start === end ? formatDay(start) : `${formatDay(start)} – ${formatDay(end)}`
  }
  const start = parisDate(event.starts_at)
  const end = parisDate(event.ends_at)
  if (start === end) return `${formatDay(start)} · ${clock(event.starts_at)} – ${clock(event.ends_at)}`
  return `${formatDay(start)} ${clock(event.starts_at)} – ${formatDay(end)} ${clock(event.ends_at)}`
}

function describeRotation(rotation: RotationWeek) {
  const slot = rotation.starts_on === rotation.ends_on
    ? formatDay(rotation.starts_on)
    : `${formatDay(rotation.starts_on)} – ${formatDay(rotation.ends_on)}`
  return `${slot} · ${rotation.user.first_name}`
}

function rotationRule(rotation: RotationWeek) {
  const days = rotation.turn_days > 1 ? 'jours' : 'jour'
  const pause = rotation.offset_days === 0
    ? 'Les passages s’enchaînent.'
    : `Pause de ${rotation.offset_days} jour${rotation.offset_days > 1 ? 's' : ''} entre deux personnes.`
  return `À partir du ${formatDay(rotation.rule_starts_on)}. Chaque passage dure ${rotation.turn_days} ${days}. ${pause}`
}

function recurrenceLabel(event: CalendarEvent) {
  if (event.recurrence === 'daily') return 'Chaque jour'
  if (event.recurrence === 'monthly') return 'Chaque mois'
  const names = ['', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche']
  const days = event.weekdays.map((day) => names[day]).join(', ')
  if (event.recurrence === 'biweekly') return `Toutes les 2 semaines (${days})`
  return `Chaque semaine (${days})`
}
</script>

<template>
  <q-page class="page wide" @pointerdown="onPointerDown">
    <div class="row items-center no-wrap q-mb-sm">
      <q-btn flat round icon="chevron_left" aria-label="Période précédente" @click="shift(-1)" />
      <h1 class="planning-heading">
        <span :class="{ 'today-pill': mode === 'day' && cursor === todayIso() }">{{ heading }}</span>
      </h1>
      <q-btn flat round icon="chevron_right" aria-label="Période suivante" @click="shift(1)" />
    </div>
    <div class="row items-center q-gutter-sm q-mb-sm">
      <q-btn-toggle
        :model-value="mode"
        no-caps
        toggle-color="primary"
        :options="modeOptions"
        @update:model-value="setMode"
      />
      <q-btn outline no-caps color="primary" label="Aujourd’hui" @click="cursor = todayIso()" />
      <q-space />
      <q-btn round unelevated color="primary" icon="add" aria-label="Ajouter">
        <q-menu ref="addMenu" anchor="bottom right" self="top right">
          <q-list class="add-menu">
            <q-item clickable @click="createFromMenu('event')">
              <q-item-section>Événement</q-item-section>
            </q-item>
            <q-item clickable @click="createFromMenu('rotation')">
              <q-item-section>Tour</q-item-section>
            </q-item>
          </q-list>
        </q-menu>
      </q-btn>
    </div>
    <div class="calendar-stage" :class="slideClass">
      <div v-if="loading && !periodReady" class="row justify-center q-pb-sm">
        <q-spinner color="primary" size="24px" />
      </div>
      <MonthGrid
        v-if="mode === 'month'"
        :month="cursor.slice(0, 7)"
        :days="visibleDays"
        :events="visiblePayload.events"
        :rotations="visiblePayload.rotations"
        @open-day="openDay"
        @open-event="openEvent"
        @open-rotation="openRotation"
      />
      <DayAgenda
        v-else-if="mode === 'day'"
        :day="cursor"
        :events="visiblePayload.events"
        :rotations="visiblePayload.rotations"
        @open-event="openEvent"
        @open-rotation="openRotation"
      />
      <TimeGrid
        v-else
        :days="visibleDays"
        :events="visiblePayload.events"
        :rotations="visiblePayload.rotations"
        @open-day="openDay"
        @open-event="openEvent"
        @open-rotation="openRotation"
      />
    </div>
    <q-banner v-if="errors.length" class="bg-negative text-white q-mt-md" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>

    <q-dialog class="planning-dialog" position="bottom" :model-value="panel !== null" @update:model-value="closePanel">
      <q-card v-if="panel" class="sheet-card q-pa-md">
        <EventForm
          v-if="panel.kind === 'event'"
          :key="`event-form-${formKey}`"
          :coloc-id="colocId"
          :mode="panel.mode"
          :event="panel.event"
          :initial-date="cursor"
          :members="coloc?.members ?? []"
          :can-choose-reminders="canChooseReminders(panel)"
          @saved="onSaved"
          @cancel="panel = null"
        />
        <RotationForm
          v-else-if="panel.kind === 'rotation' && coloc"
          :key="`rotation-form-${formKey}`"
          :coloc-id="colocId"
          :members="coloc.members"
          :rotation="panel.rotation"
          :initial-date="cursor"
          @saved="onSaved"
          @cancel="panel = null"
        />
        <div v-else-if="panel.kind === 'rotation'" key="rotation-loading" class="row justify-center q-pa-lg">
          <q-spinner color="primary" size="32px" />
        </div>
        <template v-else-if="panel.kind === 'event-detail'">
          <h2 class="text-h6 q-mt-none q-mb-sm">{{ panel.event.title }}</h2>
          <p>{{ describeEvent(panel.event) }}</p>
          <p v-if="panel.event.recurring" class="muted">{{ recurrenceLabel(panel.event) }}</p>
          <p v-if="panel.event.notes" class="q-mt-md">{{ panel.event.notes }}</p>
          <p v-if="user && panel.event.remind_user_ids.includes(user.id)" class="muted q-mb-none">
            Le créateur t’a ajouté aux rappels.
          </p>
          <div class="column q-gutter-sm q-mt-md">
            <q-btn
              v-if="user"
              outline
              no-caps
              color="primary"
              :loading="reminding"
              :label="panel.event.subscribed ? 'Ne plus m’abonner' : 'M’abonner au rappel'"
              @click="toggleReminder(panel.event)"
            />
            <template v-if="panel.event.recurring">
              <q-btn color="primary" unelevated no-caps label="Modifier ce jour-ci" @click="editEvent(panel.event, 'occurrence')" />
              <q-btn outline no-caps color="primary" label="Modifier la série" @click="editEvent(panel.event, 'series')" />
              <q-btn outline no-caps color="negative" label="Supprimer ce jour-ci" @click="removeEvent(panel.event, panel.event.occurrence_on)" />
              <q-btn outline no-caps color="negative" label="Supprimer la série" @click="removeEvent(panel.event)" />
            </template>
            <template v-else>
              <q-btn color="primary" unelevated no-caps label="Modifier" @click="editEvent(panel.event, 'series')" />
              <q-btn outline no-caps color="negative" label="Supprimer" @click="removeEvent(panel.event)" />
            </template>
          </div>
        </template>
        <template v-else>
          <h2 class="text-h6 q-mt-none q-mb-sm">{{ panel.rotation.title }}</h2>
          <p>{{ describeRotation(panel.rotation) }}</p>
          <p class="muted">{{ rotationRule(panel.rotation) }}</p>
          <div class="column q-gutter-sm q-mt-md">
            <q-btn color="primary" unelevated no-caps label="Modifier le tour" @click="editRotation(panel.rotation)" />
            <q-btn outline no-caps color="negative" label="Supprimer le tour" @click="removeRotation(panel.rotation)" />
          </div>
        </template>
      </q-card>
    </q-dialog>
  </q-page>
</template>
