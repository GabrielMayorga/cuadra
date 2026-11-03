import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

// Cliente para Server Components, Route Handlers y Server Actions.
// Lee/escribe la sesión en las cookies de la petición. El try/catch en
// setAll no es un error silenciado a lo loco: un Server Component no
// puede escribir cookies (Next lo bloquea), y no pasa nada porque el
// middleware (pieza 2-2) ya refresca la sesión en cada request antes de
// que esto se ejecute.
export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // ver comentario arriba.
          }
        },
      },
    }
  )
}
