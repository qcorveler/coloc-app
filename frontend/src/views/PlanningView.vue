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
import {
  deleteEvent,
  deleteRotation,
  fetchCalendar,
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
const colocId = computed(() => String(route.params.id))
const coloc = ref<Coloc | null>(null)
const payload = ref<CalendarPayload>({ events: [], rotations: [] })
const mode = ref<'month' | 'week' | 'day'>('month')
const modeOptions = [
  { label: 'Mois', value: 'month' },
  { label: 'Semaine', value: 'week' },
  { label: 'Jour', value: 'day' },
]
const cursor = ref(todayIso())
const loading = ref(true)
const errors = ref<string[]>([])

type Panel =
  | { kind: 'event'; mode: 'create' | 'occurrence' | 'series'; event: CalendarEvent | null }
  | { kind: 'rotation'; rotation: RotationWeek | null }
  | { kind: 'event-detail'; event: CalendarEvent }
  | { kind: 'rotation-detail'; rotation: RotationWeek }

const panel = ref<Panel | null>(null)
const slideClass = ref('')
const addMenu = ref<{ hide: () => void } | null>(null)
let swipeOrigin: { x: number; y: number } | null = null

const range = computed(() => {
  if (mode.value === 'month') {
    const days = monthGrid(cursor.value)
    return { from: days[0], to: days[days.length - 1] }
  }
  if (mode.value === 'week') {
    const days = weekDates(cursor.value)
    return { from: days[0], to: days[6] }
  }
  return { from: cursor.value, to: cursor.value }
})

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
watch([colocId, () => range.value.from, () => range.value.to], loadCalendar, { immediate: true })

async function loadColoc() {
  try {
    coloc.value = await fetchColoc(colocId.value)
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger la coloc']
  }
}

async function loadCalendar() {
  loading.value = true
  try {
    payload.value = await fetchCalendar(colocId.value, range.value.from, range.value.to)
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger le planning']
  } finally {
    loading.value = false
  }
}

function setMode(value: string | number | null) {
  if (value === 'month' || value === 'week' || value === 'day') mode.value = value
}

function closePanel(open: boolean) {
  if (!open) panel.value = null
}

function shift(direction: number) {
  if (mode.value === 'month') cursor.value = addMonths(cursor.value, direction)
  else if (mode.value === 'week') cursor.value = addDays(cursor.value, direction * 7)
  else cursor.value = addDays(cursor.value, direction)
  slideClass.value = ''
  requestAnimationFrame(() => {
    slideClass.value = direction > 0 ? 'slide-next' : 'slide-prev'
  })
}

function onPointerDown(event: PointerEvent) {
  if (event.button !== 0) return
  cancelPointer()
  swipeOrigin = { x: event.clientX, y: event.clientY }
  window.addEventListener('pointerup', finishPointer)
  window.addEventListener('pointercancel', cancelPointer)
}

function cancelPointer() {
  swipeOrigin = null
  window.removeEventListener('pointerup', finishPointer)
  window.removeEventListener('pointercancel', cancelPointer)
}

function finishPointer(event: PointerEvent) {
  window.removeEventListener('pointerup', finishPointer)
  window.removeEventListener('pointercancel', cancelPointer)
  if (!swipeOrigin) return
  const dx = event.clientX - swipeOrigin.x
  const dy = event.clientY - swipeOrigin.y
  swipeOrigin = null
  if (Math.abs(dx) < 50 || Math.abs(dx) < Math.abs(dy) * 1.5) return
  shift(dx < 0 ? 1 : -1)
  const stopClick = (click: Event) => {
    click.preventDefault()
    click.stopPropagation()
    window.removeEventListener('click', stopClick, true)
  }
  window.addEventListener('click', stopClick, true)
}

function createFromMenu(kind: 'event' | 'rotation') {
  addMenu.value?.hide()
  if (kind === 'event') openCreateEvent()
  else openCreateRotation()
}

onUnmounted(cancelPointer)

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

function editEvent(event: CalendarEvent, editMode: 'occurrence' | 'series') {
  panel.value = { kind: 'event', mode: editMode, event }
}

function editRotation(rotation: RotationWeek) {
  panel.value = { kind: 'rotation', rotation }
}

async function onSaved() {
  panel.value = null
  await loadCalendar()
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
    await loadCalendar()
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de supprimer l’événement']
  }
}

async function removeRotation(rotation: RotationWeek) {
  if (!(await confirm('Supprimer ce tour ?', 'Supprimer', 'negative'))) return
  try {
    await deleteRotation(colocId.value, rotation.id)
    panel.value = null
    await loadCalendar()
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
  return `Chaque semaine (${event.weekdays.map((day) => names[day]).join(', ')})`
}
</script>

<template>
  <q-page class="page wide">
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
    <div
      class="calendar-stage"
      :class="slideClass"
      @pointerdown="onPointerDown"
    >
      <div v-if="loading" class="row justify-center q-pa-md">
        <q-spinner color="primary" size="32px" />
      </div>
      <MonthGrid
        v-else-if="mode === 'month'"
        :month="cursor.slice(0, 7)"
        :days="visibleDays"
        :events="payload.events"
        :rotations="payload.rotations"
        @open-day="openDay"
        @open-event="openEvent"
        @open-rotation="openRotation"
      />
      <DayAgenda
        v-else-if="mode === 'day'"
        :day="cursor"
        :events="payload.events"
        :rotations="payload.rotations"
        @open-event="openEvent"
        @open-rotation="openRotation"
      />
      <TimeGrid
        v-else
        :days="visibleDays"
        :events="payload.events"
        :rotations="payload.rotations"
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
          :key="formKey"
          :coloc-id="colocId"
          :mode="panel.mode"
          :event="panel.event"
          :initial-date="cursor"
          @saved="onSaved"
          @cancel="panel = null"
        />
        <RotationForm
          v-else-if="panel.kind === 'rotation' && coloc"
          :key="formKey"
          :coloc-id="colocId"
          :members="coloc.members"
          :rotation="panel.rotation"
          :initial-date="cursor"
          @saved="onSaved"
          @cancel="panel = null"
        />
        <div v-else-if="panel.kind === 'rotation'" class="row justify-center q-pa-lg">
          <q-spinner color="primary" size="32px" />
        </div>
        <template v-else-if="panel.kind === 'event-detail'">
          <h2 class="text-h6 q-mt-none q-mb-sm">{{ panel.event.title }}</h2>
          <p>{{ describeEvent(panel.event) }}</p>
          <p v-if="panel.event.recurring" class="muted">{{ recurrenceLabel(panel.event) }}</p>
          <p v-if="panel.event.notes" class="q-mt-md">{{ panel.event.notes }}</p>
          <div class="column q-gutter-sm q-mt-md">
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
