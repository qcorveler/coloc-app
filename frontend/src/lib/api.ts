export type User = {
  id: number
  email: string
  first_name: string
  last_name: string
  date_of_birth: string
}

export class ApiError extends Error {
  status: number
  errors: string[]

  constructor(status: number, errors: string[]) {
    super(errors[0] ?? 'Une erreur est survenue')
    this.name = 'ApiError'
    this.status = status
    this.errors = errors
  }
}

function apiOrigin() {
  return (import.meta.env.VITE_API_URL ?? '').replace(/\/$/, '')
}

export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers)
  if (options.body && !(options.body instanceof FormData) && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json')
  }

  const response = await fetch(`${apiOrigin()}${path}`, {
    ...options,
    headers,
    credentials: 'include',
  })

  if (response.status === 204) {
    return undefined as T
  }

  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    const record = data as { errors?: unknown; error?: unknown }
    const errors = Array.isArray(record.errors)
      ? record.errors.map(String)
      : [typeof record.error === 'string' ? record.error : 'Une erreur est survenue']
    throw new ApiError(response.status, errors)
  }

  return data as T
}
