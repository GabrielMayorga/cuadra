'use client'

import { useState, type FormEvent } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

function mensajeDeError(message: string): string {
  if (/invalid login credentials/i.test(message)) return 'Correo o contraseña incorrectos.'
  if (/email not confirmed/i.test(message)) return 'Tu correo aún no está confirmado.'
  return 'No se pudo iniciar sesión. Inténtalo de nuevo.'
}

export function LoginForm() {
  const router = useRouter()
  const [correo, setCorreo] = useState('')
  const [contrasena, setContrasena] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [cargando, setCargando] = useState(false)

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setError(null)
    setCargando(true)
    try {
      const supabase = createClient()
      const { error } = await supabase.auth.signInWithPassword({
        email: correo.trim(),
        password: contrasena,
      })
      if (error) {
        setError(mensajeDeError(error.message))
        return
      }
      router.refresh()
      router.push('/')
    } catch {
      setError('No se pudo conectar con el servidor. Revisa tu conexión.')
    } finally {
      setCargando(false)
    }
  }

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-4" noValidate>
      <label className="flex flex-col gap-1.5 text-sm font-medium text-neutral-800">
        Correo
        <input
          type="email"
          name="correo"
          autoComplete="username"
          required
          value={correo}
          onChange={(e) => setCorreo(e.target.value)}
          className="rounded-lg border border-neutral-300 bg-white px-3 py-2.5 text-base font-normal outline-none focus:border-[#003c1d] focus:ring-2 focus:ring-[#003c1d]/20"
        />
      </label>
      <label className="flex flex-col gap-1.5 text-sm font-medium text-neutral-800">
        Contraseña
        <input
          type="password"
          name="contrasena"
          autoComplete="current-password"
          required
          value={contrasena}
          onChange={(e) => setContrasena(e.target.value)}
          className="rounded-lg border border-neutral-300 bg-white px-3 py-2.5 text-base font-normal outline-none focus:border-[#003c1d] focus:ring-2 focus:ring-[#003c1d]/20"
        />
      </label>

      {error && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </p>
      )}

      <button
        type="submit"
        disabled={cargando || !correo || !contrasena}
        className="mt-1 rounded-lg bg-[#003c1d] px-4 py-2.5 text-base font-semibold text-white transition-colors hover:bg-[#00522a] disabled:cursor-not-allowed disabled:opacity-60"
      >
        {cargando ? 'Ingresando…' : 'Ingresar'}
      </button>
    </form>
  )
}
