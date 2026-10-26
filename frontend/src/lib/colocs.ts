import { api } from './api'

export type ColocSummary = {
  id: number
  name: string
  address: string
  photo_url: string | null
  member_count: number
}

export type ColocMember = {
  id: number
  first_name: string
  last_name: string
  avatar_url: string | null
}

export type Coloc = ColocSummary & {
  description: string | null
  invite_token: string
  members: ColocMember[]
}

export type ColocFields = {
  name: string
  address: string
  description: string
  photo: File | null
  removePhoto: boolean
}

export function initial(name: string) {
  return name.trim().charAt(0).toUpperCase() || '?'
}

export function inviteLink(token: string) {
  return `${window.location.origin}/rejoindre/${token}`
}

export async function listColocs() {
  const data = await api<{ colocs: ColocSummary[] }>('/api/colocs')
  return data.colocs
}

export async function fetchColoc(id: number | string) {
  const data = await api<{ coloc: Coloc }>(`/api/colocs/${id}`)
  return data.coloc
}

export async function fetchInvitation(token: string) {
  const data = await api<{ coloc: ColocSummary }>(`/api/invitations/${token}`)
  return data.coloc
}

export async function joinColoc(token: string) {
  const data = await api<{ coloc: Coloc }>(`/api/invitations/${token}`, {
    method: 'POST',
    body: '{}',
  })
  return data.coloc
}

export async function saveColoc(id: number | null, fields: ColocFields) {
  const path = id === null ? '/api/colocs' : `/api/colocs/${id}`
  const method = id === null ? 'POST' : 'PATCH'
  const data = fields.photo || fields.removePhoto
    ? await api<{ coloc: Coloc }>(path, { method, body: formData(fields), headers: requestedWith() })
    : await api<{ coloc: Coloc }>(path, { method, body: JSON.stringify(jsonBody(fields)) })
  return data.coloc
}

export async function regenerateInvite(id: number) {
  const data = await api<{ coloc: Coloc }>(`/api/colocs/${id}/invitation`, {
    method: 'POST',
    body: '{}',
  })
  return data.coloc
}

export async function leaveColoc(id: number) {
  await api<void>(`/api/colocs/${id}/membership`, { method: 'DELETE' })
}

function jsonBody(fields: ColocFields) {
  return {
    name: fields.name,
    address: fields.address,
    description: fields.description,
  }
}

function formData(fields: ColocFields) {
  const form = new FormData()
  form.set('name', fields.name)
  form.set('address', fields.address)
  form.set('description', fields.description)
  if (fields.photo) form.set('photo', fields.photo)
  if (fields.removePhoto) form.set('remove_photo', 'true')
  return form
}

function requestedWith() {
  const headers = new Headers()
  headers.set('X-Requested-With', 'XMLHttpRequest')
  return headers
}
