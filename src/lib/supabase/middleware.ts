import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

const RUTAS_PUBLICAS = ['/login']

function redirigir(request: NextRequest, response: NextResponse, pathname: string) {
  const url = request.nextUrl.clone()
  url.pathname = pathname
  const redireccion = NextResponse.redirect(url)
  // Conserva las cookies de sesión recién refrescadas; sin esto el
  // redirect las pierde y el usuario queda en un bucle de login.
  response.cookies.getAll().forEach((c) => redireccion.cookies.set(c))
  return redireccion
}

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          response = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  // getUser() valida el token contra el servidor de Auth. getSession()
  // solo lee la cookie, que el cliente puede falsificar: nunca la uses
  // para decidir acceso.
  const {
    data: { user },
  } = await supabase.auth.getUser()

  const { pathname } = request.nextUrl
  const esPublica = RUTAS_PUBLICAS.some((r) => pathname === r || pathname.startsWith(r + '/'))

  if (!user && !esPublica) return redirigir(request, response, '/login')
  if (user && pathname === '/login') return redirigir(request, response, '/')

  return response
}
