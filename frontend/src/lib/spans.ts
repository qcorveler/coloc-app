import type { CalendarEvent } from './calendar'
import { addDays, clock, dayDelta, inclusiveEndDate, parisDate } from './dates'

export type SpanSource = {
  key: string
  label: string
  color: string
  start: string
  end: string
}

export type SpanSegment = {
  startCol: number
  endCol: number
  first: boolean
  continuesAfter: boolean
}

export type LaidSpan<T extends SpanSource> = T & SpanSegment & { lane: number }

export function eventBounds(event: CalendarEvent) {
  const start = parisDate(event.starts_at)
  const end = event.all_day ? inclusiveEndDate(event.ends_at) : timedEnd(event.ends_at)
  return { start, end: end < start ? start : end }
}

export function segmentOnWeek(rangeStart: string, rangeEnd: string, week: string[]): SpanSegment | null {
  if (week.length === 0) return null
  const weekStart = week[0]
  const weekEnd = week[week.length - 1]
  if (rangeEnd < weekStart || rangeStart > weekEnd) return null

  const start = rangeStart > weekStart ? rangeStart : weekStart
  const end = rangeEnd < weekEnd ? rangeEnd : weekEnd
  return {
    startCol: dayDelta(weekStart, start) + 1,
    endCol: dayDelta(weekStart, end) + 2,
    first: rangeStart >= weekStart,
    continuesAfter: rangeEnd > weekEnd,
  }
}

export function layoutWeek<T extends SpanSource>(items: T[], week: string[]): Array<LaidSpan<T>> {
  const segments = items
    .flatMap((item) => {
      const segment = segmentOnWeek(item.start, item.end, week)
      return segment ? [{ ...item, ...segment }] : []
    })
    .sort((a, b) => a.startCol - b.startCol || b.endCol - a.endCol || a.label.localeCompare(b.label, 'fr'))

  const laneEnds: number[] = []
  return segments.map((segment) => {
    let lane = laneEnds.findIndex((end) => end <= segment.startCol)
    if (lane === -1) {
      lane = laneEnds.length
      laneEnds.push(segment.endCol)
    } else {
      laneEnds[lane] = segment.endCol
    }
    return { ...segment, lane: lane + 1 }
  })
}

export function laneCount<T extends SpanSource>(spans: Array<LaidSpan<T>>) {
  return spans.reduce((max, span) => Math.max(max, span.lane), 0)
}

function timedEnd(endsAt: string) {
  const end = parisDate(endsAt)
  return clock(endsAt) === '00:00' ? addDays(end, -1) : end
}
