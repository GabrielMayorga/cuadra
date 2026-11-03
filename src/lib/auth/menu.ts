// Menú lateral por rol y módulos contratados.
// OJO: esto es solo UX (qué enlaces se muestran). La seguridad real es RLS en la BD.

export type Rol = 'dueno' | 'contador' | 'admin' | 'encargado' | 'cajero'

export type ItemMenu = {
  etiqueta: string
  ruta: string
  /** Código del catálogo public.modulos, o null si el ítem no tiene módulo equivalente. */
  modulo: string | null
  roles: readonly Rol[]
}

const TODOS_MENOS_CAJERO: readonly Rol[] = ['dueno', 'contador', 'admin', 'encargado']
const GLOBALES: readonly Rol[] = ['dueno', 'contador', 'admin']

// Claves de `modulo` = public.modulos.codigo (migración 20261026034329_modulos_tipos_cambio.sql).
// Dashboard y Configuración NO tienen módulo en el catálogo: modulo = null (siempre visibles según rol).
export const MENU: readonly ItemMenu[] = [
  { etiqueta: 'Dashboard', ruta: '/dashboard', modulo: null, roles: TODOS_MENOS_CAJERO },
  { etiqueta: 'Arqueo', ruta: '/arqueo', modulo: 'arqueo', roles: [...TODOS_MENOS_CAJERO, 'cajero'] },
  { etiqueta: 'Ingresos y gastos', ruta: '/ingresos-gastos', modulo: 'ingresos_gastos', roles: TODOS_MENOS_CAJERO },
  { etiqueta: 'Cuentas por cobrar', ruta: '/cxc', modulo: 'cxc', roles: TODOS_MENOS_CAJERO },
  { etiqueta: 'Proveedores', ruta: '/proveedores', modulo: 'proveedores', roles: TODOS_MENOS_CAJERO },
  { etiqueta: 'Planilla', ruta: '/planilla', modulo: 'planilla', roles: GLOBALES },
  { etiqueta: 'Reportes', ruta: '/reportes', modulo: 'reportes', roles: GLOBALES },
  { etiqueta: 'Configuración', ruta: '/configuracion', modulo: null, roles: ['dueno', 'admin'] },
]

/**
 * Ítems visibles para un rol. `modulosContratados` son los códigos con
 * empresa_modulos.contratado = true; un ítem con módulo no contratado se oculta.
 */
export function menuPara(rol: Rol, modulosContratados: readonly string[]): ItemMenu[] {
  const contratados = new Set(modulosContratados)
  return MENU.filter(
    (item) => item.roles.includes(rol) && (item.modulo === null || contratados.has(item.modulo)),
  )
}
