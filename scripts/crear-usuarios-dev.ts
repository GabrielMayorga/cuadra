// Crea usuarios de DESARROLLO (uno por rol) en el Supabase local. Idempotente.
// Uso: pnpm db:seed-usuarios   (requiere `pnpm db:reset` previo para que exista la empresa del seed)
// La service role key se lee SOLO de SUPABASE_SERVICE_ROLE_KEY (.env.local); nunca va en el código.
import { createClient } from '@supabase/supabase-js'

const url = process.env.NEXT_PUBLIC_SUPABASE_URL
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!url || !serviceKey) {
  console.error('Faltan NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en .env.local')
  process.exit(1)
}
if (!/^https?:\/\/(127\.0\.0\.1|localhost)(:|\/|$)/.test(url)) {
  console.error(`Rechazado: ${url} no es un Supabase local. Este script es solo para desarrollo.`)
  process.exit(1)
}

const PASSWORD_DEV = 'cuadra-dev-1234' // solo desarrollo
const EMPRESA = '00000000-0000-0000-0000-00000000e001'
const SUC_FER1 = '00000000-0000-0000-0000-0000000a1a01'

type Rol = 'dueno' | 'contador' | 'admin' | 'encargado' | 'cajero'
const USUARIOS: { id: string; email: string; nombre: string; rol: Rol; sucursal?: string }[] = [
  { id: '00000000-0000-0000-0000-0000000000d1', email: 'dueno@example.test', nombre: 'Dueño Ejemplo', rol: 'dueno' },
  { id: '00000000-0000-0000-0000-0000000000c0', email: 'contador@example.test', nombre: 'Contador Ejemplo', rol: 'contador' },
  { id: '00000000-0000-0000-0000-0000000000ad', email: 'admin@example.test', nombre: 'Admin Ejemplo', rol: 'admin' },
  { id: '00000000-0000-0000-0000-0000000000e1', email: 'encargado@example.test', nombre: 'Encargado Ejemplo', rol: 'encargado', sucursal: SUC_FER1 },
  { id: '00000000-0000-0000-0000-0000000000c1', email: 'cajero@example.test', nombre: 'Cajero Ejemplo', rol: 'cajero', sucursal: SUC_FER1 },
]

const supabase = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })

async function main() {
  const { data: empresa, error: errEmpresa } = await supabase.from('empresas').select('id').eq('id', EMPRESA).maybeSingle()
  if (errEmpresa || !empresa) {
    throw new Error(`No existe la empresa del seed (${errEmpresa?.message ?? 'vacía'}). Corre pnpm db:reset primero.`)
  }

  for (const u of USUARIOS) {
    const { error } = await supabase.auth.admin.createUser({
      id: u.id,
      email: u.email,
      password: PASSWORD_DEV,
      email_confirm: true,
    })
    if (error && !/already|registered|exists/i.test(error.message)) throw new Error(`${u.email}: ${error.message}`)
    console.log(`${error ? 'ya existe' : 'creado   '}  ${u.rol.padEnd(9)} ${u.email}`)

    const { error: errPerfil } = await supabase
      .from('perfiles')
      .upsert({ id: u.id, empresa_id: EMPRESA, nombre: u.nombre, rol: u.rol, activo: true })
    if (errPerfil) throw new Error(`perfil ${u.email}: ${errPerfil.message}`)

    if (u.sucursal) {
      const { error: errAsig } = await supabase
        .from('perfil_sucursales')
        .upsert({ empresa_id: EMPRESA, perfil_id: u.id, sucursal_id: u.sucursal })
      if (errAsig) throw new Error(`asignación ${u.email}: ${errAsig.message}`)
    }
  }
  console.log(`\nListo. Contraseña de desarrollo para todos: ${PASSWORD_DEV}`)
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e)
  process.exit(1)
})
