import { Suspense, type ReactNode } from 'react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { cerrarSesion } from '@/lib/auth/actions'
import { menuPara, type Rol } from '@/lib/auth/menu'

const ETIQUETA_ROL: Record<Rol, string> = {
  dueno: 'Dueño',
  contador: 'Contador',
  admin: 'Administrador',
  encargado: 'Encargado',
  cajero: 'Cajero',
}

function BotonCerrarSesion() {
  return (
    <form action={cerrarSesion}>
      <button
        type="submit"
        className="rounded-lg border border-neutral-300 bg-white px-3 py-1.5 text-sm font-medium text-neutral-800 hover:bg-neutral-50"
      >
        Cerrar sesión
      </button>
    </form>
  )
}

// Lee cookies (dato dinámico): con cacheComponents debe vivir dentro de <Suspense>.
async function Shell({ children }: { children: ReactNode }) {
  const supabase = await createClient()
  // getUser() valida el token; el proxy ya redirigió a /login si no hay sesión.
  const {
    data: { user },
  } = await supabase.auth.getUser()

  const { data: perfil } = user
    ? await supabase
        .from('perfiles')
        .select('nombre, rol')
        .eq('id', user.id)
        .maybeSingle()
    : { data: null }

  if (!user || !perfil) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center gap-4 p-6 text-center">
        <p className="text-neutral-700">Tu usuario no tiene un perfil asignado. Contacta al administrador.</p>
        <BotonCerrarSesion />
      </main>
    )
  }

  // RLS ya limita empresa_modulos a la empresa del usuario.
  const { data: modulos } = await supabase.from('empresa_modulos').select('modulo').eq('contratado', true)
  const rol = perfil.rol as Rol
  const items = menuPara(rol, (modulos ?? []).map((m) => m.modulo))
  // RLS limita empresas a la del usuario.
  const { data: empresaFila } = await supabase.from('empresas').select('nombre').maybeSingle()
  const empresa = empresaFila?.nombre

  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      <aside className="bg-[#003c1d] text-white md:w-64 md:shrink-0">
        <div className="px-5 py-4 md:py-6">
          <p className="text-xl font-bold">Cuadra</p>
          {empresa && <p className="truncate text-xs text-white/70">{empresa}</p>}
        </div>
        <nav className="flex gap-1 overflow-x-auto px-3 pb-3 md:flex-col md:overflow-visible md:pb-6">
          {items.map((item) => (
            <Link
              key={item.ruta}
              href={item.ruta}
              className="whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium text-white/90 hover:bg-white/10 hover:text-white"
            >
              {item.etiqueta}
            </Link>
          ))}
        </nav>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center justify-between gap-3 border-b border-black/5 bg-white px-4 py-3 sm:px-6">
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold text-neutral-900">{perfil.nombre}</p>
            <p className="text-xs text-neutral-500">{ETIQUETA_ROL[rol]}</p>
          </div>
          <BotonCerrarSesion />
        </header>
        <main className="flex-1 p-4 sm:p-6">{children}</main>
      </div>
    </div>
  )
}

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <Suspense fallback={<div className="p-6 text-sm text-neutral-500">Cargando…</div>}>
      <Shell>{children}</Shell>
    </Suspense>
  )
}
