import { api } from './api'

export type Profile = {
  id: number
  first_name: string
  last_name: string
  description: string | null
  mood: string | null
  pronouns: string | null
  date_of_birth: string
  arrived_on: string
  avatar_url: string | null
}

export type ProfileFields = {
  first_name: string
  last_name: string
  description: string
  mood: string
  pronouns: string
  date_of_birth: string
  arrived_on: string
  avatar: File | null
  removeAvatar: boolean
}

export async function fetchProfile(colocId: number | string, userId: number | string) {
  const data = await api<{ profile: Profile }>(`/api/colocs/${colocId}/profiles/${userId}`)
  return data.profile
}

export async function saveProfile(colocId: number | string, userId: number | string, fields: ProfileFields) {
  const path = `/api/colocs/${colocId}/profiles/${userId}`
  const data = fields.avatar || fields.removeAvatar
    ? await api<{ profile: Profile }>(path, { method: 'PATCH', body: formData(fields), headers: requestedWith() })
    : await api<{ profile: Profile }>(path, { method: 'PATCH', body: JSON.stringify(jsonBody(fields)) })
  return data.profile
}

function jsonBody(fields: ProfileFields) {
  return {
    first_name: fields.first_name,
    last_name: fields.last_name,
    description: fields.description,
    mood: fields.mood,
    pronouns: fields.pronouns,
    date_of_birth: fields.date_of_birth,
    arrived_on: fields.arrived_on,
  }
}

function formData(fields: ProfileFields) {
  const form = new FormData()
  form.set('first_name', fields.first_name)
  form.set('last_name', fields.last_name)
  form.set('description', fields.description)
  form.set('mood', fields.mood)
  form.set('pronouns', fields.pronouns)
  form.set('date_of_birth', fields.date_of_birth)
  form.set('arrived_on', fields.arrived_on)
  if (fields.avatar) form.set('avatar', fields.avatar)
  if (fields.removeAvatar) form.set('remove_avatar', 'true')
  return form
}

function requestedWith() {
  const headers = new Headers()
  headers.set('X-Requested-With', 'XMLHttpRequest')
  return headers
}
