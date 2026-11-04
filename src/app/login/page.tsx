import type { Metadata } from 'next'
import { LoginForm } from './login-form'

export const metadata: Metadata = { title: 'Ingresar · Cuadra' }

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-sm ring-1 ring-black/5 sm:p-8">
        <h1 className="text-2xl font-bold text-[#003c1d]">Cuadra</h1>
        <p className="mb-6 mt-1 text-sm text-neutral-600">Inicia sesión para continuar</p>
        <LoginForm />
        <p className="mt-6 text-center text-xs text-neutral-500">by Nuvix</p>
      </div>
    </main>
  )
}
