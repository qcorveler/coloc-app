<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import EventForm from '../components/planning/EventForm.vue'
import MonthGrid from '../components/planning/MonthGrid.vue'
import RotationForm from '../components/planning/RotationForm.vue'
import TimeGrid from '../components/planning/TimeGrid.vue'
import { ApiError } from '../lib/api'
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
const cursor = ref(todayIso())
const loading = ref(true)
const errors = ref<string[]>([])

type Panel =
  | { kind: 'event'; mode: 'create' | 'occurrence' | 'series'; event: CalendarEvent | null }
  | { kind: 'rotation'; rotation: RotationWeek | null }
  | { kind: 'event-detail'; event: CalendarEvent }
  | { kind: 'rotation-detail'; rotation: RotationWeek }

const panel = ref<Panel | null>(null)

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

function shift(direction: number) {
  if (mode.value === 'month') cursor.value = addMonths(cursor.value, direction)
  else if (mode.value === 'week') cursor.value = addDays(cursor.value, direction * 7)
  else cursor.value = addDays(cursor.value, direction)
}

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
  if (!window.confirm(message)) return
  try {
    await deleteEvent(colocId.value, event.id, occurrence)
    panel.value = null
    await loadCalendar()
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de supprimer l’événement']
  }
}

async function removeRotation(rotation: RotationWeek) {
  if (!window.confirm('Supprimer ce tour ?')) return
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
  return `${formatDay(rotation.starts_on)} – ${formatDay(rotation.ends_on)} · ${rotation.user.first_name}`
}

function recurrenceLabel(event: CalendarEvent) {
  if (event.recurrence === 'daily') return 'Chaque jour'
  if (event.recurrence === 'monthly') return 'Chaque mois'
  const names = ['', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche']
  return `Chaque semaine (${event.weekdays.map((day) => names[day]).join(', ')})`
}
</script>

<template>
  <main class="screen planning">
    <p class="switch"><RouterLink :to="`/colocs/${colocId}`">{{ coloc?.name ?? 'Coloc' }}</RouterLink></p>
    <div class="toolbar spread">
      <button type="button" aria-label="Période précédente" @click="shift(-1)">‹</button>
      <h1>{{ heading }}</h1>
      <button type="button" aria-label="Période suivante" @click="shift(1)">›</button>
    </div>
    <div class="toolbar">
      <button type="button" :class="{ selected: mode === 'month' }" @click="mode = 'month'">Mois</button>
      <button type="button" :class="{ selected: mode === 'week' }" @click="mode = 'week'">Semaine</button>
      <button type="button" :class="{ selected: mode === 'day' }" @click="mode = 'day'">Jour</button>
      <button type="button" @click="cursor = todayIso()">Aujourd’hui</button>
    </div>
    <div class="toolbar">
      <button type="button" class="primary" @click="openCreateEvent">Événement</button>
      <button type="button" class="primary" @click="openCreateRotation">Tour</button>
    </div>
    <p v-if="loading" class="muted">Chargement…</p>
    <MonthGrid
      v-if="mode === 'month'"
      :month="cursor.slice(0, 7)"
      :days="visibleDays"
      :events="payload.events"
      :rotations="payload.rotations"
      @open-day="openDay"
      @open-event="openEvent"
      @open-rotation="openRotation"
    />
    <TimeGrid
      v-else
      :days="visibleDays"
      :events="payload.events"
      :rotations="payload.rotations"
      :single="mode === 'day'"
      @open-day="openDay"
      @open-event="openEvent"
      @open-rotation="openRotation"
    />
    <ul v-if="errors.length" class="errors">
      <li v-for="(message, index) in errors" :key="index">{{ message }}</li>
    </ul>

    <div v-if="panel" class="sheet" @click.self="panel = null">
      <div class="sheet-card" role="dialog" aria-modal="true">
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
        <p v-else-if="panel.kind === 'rotation'">Chargement…</p>
        <template v-else-if="panel.kind === 'event-detail'">
          <h2>{{ panel.event.title }}</h2>
          <p>{{ describeEvent(panel.event) }}</p>
          <p v-if="panel.event.recurring" class="muted">{{ recurrenceLabel(panel.event) }}</p>
          <p v-if="panel.event.notes" class="lead">{{ panel.event.notes }}</p>
          <div class="actions">
            <template v-if="panel.event.recurring">
              <button type="button" class="primary" @click="editEvent(panel.event, 'occurrence')">Modifier ce jour-ci</button>
              <button type="button" class="secondary" @click="editEvent(panel.event, 'series')">Modifier la série</button>
              <button type="button" class="secondary" @click="removeEvent(panel.event, panel.event.occurrence_on)">
                Supprimer ce jour-ci
              </button>
              <button type="button" class="secondary" @click="removeEvent(panel.event)">Supprimer la série</button>
            </template>
            <template v-else>
              <button type="button" class="primary" @click="editEvent(panel.event, 'series')">Modifier</button>
              <button type="button" class="secondary" @click="removeEvent(panel.event)">Supprimer</button>
            </template>
          </div>
        </template>
        <template v-else>
          <h2>{{ panel.rotation.title }}</h2>
          <p>{{ describeRotation(panel.rotation) }}</p>
          <div class="actions">
            <button type="button" class="primary" @click="editRotation(panel.rotation)">Modifier le tour</button>
            <button type="button" class="secondary" @click="removeRotation(panel.rotation)">Supprimer le tour</button>
          </div>
        </template>
      </div>
    </div>
  </main>
</template>
