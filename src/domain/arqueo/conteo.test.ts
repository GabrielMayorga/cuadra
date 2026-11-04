import { describe, expect, it } from 'vitest'
import { nio, usd } from '@/lib/money'
import {
  DENOMINACIONES_POR_DEFECTO,
  ErrorConteo,
  formatearCorrelativo,
  totalConteo,
  type Denominacion,
} from './conteo'

function buscar(moneda: 'NIO' | 'USD', valor: number, tipo?: 'billete' | 'moneda'): Denominacion {
  const d = DENOMINACIONES_POR_DEFECTO.find(
    (x) => x.moneda === moneda && x.valor === valor && (!tipo || x.tipo === tipo),
  )
  if (!d) throw new Error(`No existe ${moneda} ${valor}`)
  return d
}
const c = (valor: number) => buscar('NIO', valor)
const d = (valor: number) => buscar('USD', valor)

describe('DENOMINACIONES_POR_DEFECTO', () => {
  it('tiene 18: 12 en C$ (7 billetes, 5 monedas) y 6 en US$', () => {
    expect(DENOMINACIONES_POR_DEFECTO).toHaveLength(18)
    const nios = DENOMINACIONES_POR_DEFECTO.filter((x) => x.moneda === 'NIO')
    expect(nios).toHaveLength(12)
    expect(nios.filter((x) => x.tipo === 'billete')).toHaveLength(7)
    expect(DENOMINACIONES_POR_DEFECTO.filter((x) => x.moneda === 'USD')).toHaveLength(6)
  })
  it('guarda valores en centavos enteros (0.10 = 10)', () => {
    expect(buscar('NIO', 10, 'moneda').valor).toBe(10)
    expect(buscar('NIO', 1000, 'billete').valor).toBe(1000)
    expect(DENOMINACIONES_POR_DEFECTO.every((x) => Number.isInteger(x.valor))).toBe(true)
  })
})

describe('totalConteo', () => {
  it('calcula el subtotal por denominación', () => {
    expect(totalConteo([{ denominacion: c(100000), cantidad: 3 }]).NIO).toBe(300000)
    expect(totalConteo([{ denominacion: c(50), cantidad: 7 }]).NIO).toBe(350)
    expect(totalConteo([{ denominacion: d(10000), cantidad: 2 }]).USD).toBe(20000)
  })
  it('3 monedas de 0.10 dan exactamente 30 centavos', () => {
    expect(totalConteo([{ denominacion: c(10), cantidad: 3 }]).NIO).toBe(30)
  })
  it('conteo vacío o con ceros da 0 en ambas monedas', () => {
    expect(totalConteo([])).toEqual({ NIO: 0, USD: 0 })
    expect(totalConteo([{ denominacion: c(100000), cantidad: 0 }])).toEqual({ NIO: 0, USD: 0 })
  })
  it('caso real del 16 oct: US$ 1,540 y C$ 22,900', () => {
    const total = totalConteo([
      { denominacion: d(10000), cantidad: 15 }, // 1,500
      { denominacion: d(2000), cantidad: 2 }, // 40
      { denominacion: c(100000), cantidad: 20 }, // 20,000
      { denominacion: c(50000), cantidad: 5 }, // 2,500
      { denominacion: c(20000), cantidad: 1 }, // 200
      { denominacion: c(10000), cantidad: 2 }, // 200
    ])
    expect(total.USD).toBe(usd(154000))
    expect(total.NIO).toBe(nio(2290000))
  })
  it('NIO y USD no se mezclan', () => {
    const total = totalConteo([
      { denominacion: c(100), cantidad: 1 }, // C$ 1 (moneda)
      { denominacion: d(100), cantidad: 1 }, // US$ 1 (billete): mismo valor, otra moneda
    ])
    expect(total).toEqual({ NIO: 100, USD: 100 })
  })
  it.each([-1, 1.5, Number.NaN, Number.POSITIVE_INFINITY])('rechaza la cantidad %s', (cantidad) => {
    expect(() => totalConteo([{ denominacion: c(100000), cantidad }])).toThrow(ErrorConteo)
  })
  it('rechaza una denominación repetida', () => {
    expect(() =>
      totalConteo([
        { denominacion: c(100000), cantidad: 1 },
        { denominacion: c(100000), cantidad: 2 },
      ]),
    ).toThrow(/repetida/)
  })
  it('rechaza un total fuera del rango de numeric(14,2)', () => {
    expect(() => totalConteo([{ denominacion: c(100000), cantidad: 10 ** 12 }])).toThrow(ErrorConteo)
  })
})

describe('formatearCorrelativo', () => {
  it('arma sucursal-caja-fecha', () => {
    expect(formatearCorrelativo('RAMA', 2, '2026-10-16')).toBe('RAMA-C2-20261016')
    expect(formatearCorrelativo('SA1', 12, '2026-01-05')).toBe('SA1-C12-20260105')
  })
  it.each(['2026-1-16', '16/10/2026', '20261016', '2026-10-16T00:00:00Z', '', '2026-13-01', '2026-02-30', '2026-00-10'])(
    'rechaza la fecha mal formada o inexistente "%s"',
    (fecha) => {
      expect(() => formatearCorrelativo('RAMA', 2, fecha)).toThrow(ErrorConteo)
    },
  )
  it('acepta el 29 de febrero solo en año bisiesto', () => {
    expect(formatearCorrelativo('RAMA', 1, '2028-02-29')).toBe('RAMA-C1-20280229')
    expect(() => formatearCorrelativo('RAMA', 1, '2026-02-29')).toThrow(ErrorConteo)
  })
  it('rechaza código de sucursal y número de caja inválidos', () => {
    expect(() => formatearCorrelativo('rama', 2, '2026-10-16')).toThrow(ErrorConteo)
    expect(() => formatearCorrelativo('R', 2, '2026-10-16')).toThrow(ErrorConteo)
    expect(() => formatearCorrelativo('RAMA', 0, '2026-10-16')).toThrow(ErrorConteo)
    expect(() => formatearCorrelativo('RAMA', 1.5, '2026-10-16')).toThrow(ErrorConteo)
  })
})
