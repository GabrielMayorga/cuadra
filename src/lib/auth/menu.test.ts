import { describe, expect, it } from 'vitest'
import { MENU, menuPara, type Rol } from './menu'

const TODOS = ['arqueo', 'ingresos_gastos', 'cxc', 'proveedores', 'planilla', 'reportes']
const etiquetas = (rol: Rol, modulos: string[] = TODOS) => menuPara(rol, modulos).map((i) => i.etiqueta)

describe('menuPara', () => {
  it('dueno ve todo', () => {
    expect(etiquetas('dueno')).toEqual([
      'Dashboard', 'Arqueo', 'Ingresos y gastos', 'Cuentas por cobrar',
      'Proveedores', 'Planilla', 'Reportes', 'Configuración',
    ])
  })

  it('contador ve todo menos Configuración', () => {
    expect(etiquetas('contador')).toEqual([
      'Dashboard', 'Arqueo', 'Ingresos y gastos', 'Cuentas por cobrar',
      'Proveedores', 'Planilla', 'Reportes',
    ])
  })

  it('admin ve todo', () => {
    expect(etiquetas('admin')).toEqual(etiquetas('dueno'))
  })

  it('encargado no ve Planilla, Reportes ni Configuración', () => {
    expect(etiquetas('encargado')).toEqual([
      'Dashboard', 'Arqueo', 'Ingresos y gastos', 'Cuentas por cobrar', 'Proveedores',
    ])
  })

  it('cajero solo ve Arqueo', () => {
    expect(etiquetas('cajero')).toEqual(['Arqueo'])
  })

  it('oculta ítems cuyo módulo no está contratado', () => {
    const e = etiquetas('dueno', ['arqueo', 'reportes'])
    expect(e).toEqual(['Dashboard', 'Arqueo', 'Reportes', 'Configuración'])
  })

  it('los ítems sin módulo en el catálogo siguen visibles aunque no haya módulos contratados', () => {
    expect(etiquetas('dueno', [])).toEqual(['Dashboard', 'Configuración'])
    expect(etiquetas('cajero', [])).toEqual([])
  })

  it('cada clave de módulo del menú existe en el catálogo', () => {
    const catalogo = new Set(TODOS)
    for (const item of MENU) if (item.modulo !== null) expect(catalogo.has(item.modulo)).toBe(true)
  })
})
