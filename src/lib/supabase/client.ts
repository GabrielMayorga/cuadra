import { createBrowserClient } from '@supabase/ssr'

// Cliente para Client Components (formularios, botones). Usa la anon key:
// nunca la service role key aquí, porque este código corre en el navegador
// y quedaría expuesta. La seguridad real la pone RLS (fase 1b-5), no esta
// llave — el anon key solo identifica "esto es una petición del cliente web".
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
