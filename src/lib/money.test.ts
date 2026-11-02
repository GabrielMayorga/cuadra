import { describe, expect, it } from 'vitest'
import {
  ErrorDinero, MAX_CENTAVOS, aBD, aCordobas, aDolares, abs, aplicarPorcentaje, comparar,
  desdeBD, esCero, formatear, negar, nio, parsear, porcentaje, restar, sumar, tasa, total, usd,
} from './money'

describe('construcción', () => {
  it('acepta enteros de centavos', () => {
    expect(nio(7918494)).toBe(7918494)
  })
  it.each([1.5, Number.NaN, Number.POSITIVE_INFINITY, Number.MAX_SAFE_INTEGER + 1])(
    'rechaza %s',
    (n) => {
      expect(() => nio(n)).toThrow(ErrorDinero)
    },
  )
  it('respeta el límite de numeric(14,2)', () => {
    expect(nio(MAX_CENTAVOS)).toBe(MAX_CENTAVOS)
    expect(() => nio(MAX_CENTAVOS + 1)).toThrow(ErrorDinero)
  })
})

describe('parsear', () => {
  it.each([
    { texto: '79,184.94', esperado: 7918494 },
    { texto: '79184.94', esperado: 7918494 },
    { texto: '1540', esperado: 154000 },
    { texto: '0.5', esperado: 50 },
    { texto: '-79.06', esperado: -7906 },
    { texto: '  22,900.00 ', esperado: 2290000 },
    { texto: '-0', esperado: 0 },
  ])('"$texto" → $esperado', ({ texto, esperado }) => {
    expect(parsear(texto, 'NIO')).toBe(esperado)
  })

  it.each(['1.234', 'abc', '', '1,23.4', '12,34', '.5', 'C$ 100'])('rechaza "%s"', (texto) => {
    expect(() => parsear(texto, 'NIO')).toThrow(ErrorDinero)
  })

  it('rechaza montos fuera de rango', () => {
    expect(() => parsear('1,000,000,000,000.00', 'NIO')).toThrow(ErrorDinero)
  })
})

describe('desdeBD y aBD', () => {
  it.each([
    { valor: '79184.94', esperado: 7918494 },
    { valor: 79184.94, esperado: 7918494 },
    { valor: '0.10', esperado: 10 },
    { valor: 0.1, esperado: 10 },
    { valor: 0.07, esperado: 7 },
    { valor: '-79.06', esperado: -7906 },
  ])('desdeBD($valor) → $esperado', ({ valor, esperado }) => {
    expect(desdeBD(valor, 'NIO')).toBe(esperado)
  })

  it.each([
    { centavos: 7918494, esperado: '79184.94' },
    { centavos: 5, esperado: '0.05' },
    { centavos: -7906, esperado: '-79.06' },
    { centavos: 0, esperado: '0.00' },
  ])('aBD($centavos) → "$esperado"', ({ centavos, esperado }) => {
    expect(aBD(nio(centavos))).toBe(esperado)
  })
})

describe('aritmética', () => {
  it('0.10 + 0.20 da 30 centavos exactos', () => {
    expect(0.1 + 0.2).not.toBe(0.3)
    expect(sumar(parsear('0.10', 'NIO'), parsear('0.20', 'NIO'))).toBe(30)
  })
  it('total de una lista', () => {
    expect(total('NIO', [nio(100), nio(250), nio(-50)])).toBe(300)
    expect(total('NIO', [])).toBe(0)
  })
  it('restar, negar, abs, comparar y esCero', () => {
    expect(restar(nio(500), nio(800))).toBe(-300)
    expect(negar(nio(0))).toBe(0)
    expect(abs(nio(-7906))).toBe(7906)
    expect(comparar(nio(1), nio(2))).toBe(-1)
    expect(comparar(nio(2), nio(2))).toBe(0)
    expect(esCero(nio(0))).toBe(true)
  })
  it('lanza si una suma sale de rango', () => {
    expect(() => sumar(nio(MAX_CENTAVOS), nio(1))).toThrow(ErrorDinero)
  })
})

describe('tasas y porcentajes', () => {
  it.each([
    { valor: '36.60', esperado: 366000 },
    { valor: '36.6', esperado: 366000 },
    { valor: 36.62, esperado: 366200 },
    { valor: 36.6243, esperado: 366243 },
  ])('tasa($valor) → $esperado', ({ valor, esperado }) => {
    expect(tasa(valor)).toBe(esperado)
  })
  it.each(['0', '-1', '36.12345', 'abc', ''])('rechaza la tasa "%s"', (valor) => {
    expect(() => tasa(valor)).toThrow(ErrorDinero)
  })
  it('porcentajes', () => {
    expect(porcentaje('15')).toBe(1500)
    expect(porcentaje('15.5')).toBe(1550)
    expect(porcentaje('100')).toBe(10000)
  })
  it.each(['101', '-5', '15.555'])('rechaza el porcentaje "%s"', (valor) => {
    expect(() => porcentaje(valor)).toThrow(ErrorDinero)
  })
})

describe('conversión y redondeo', () => {
  it('ejemplo real: US$ 1,540.00 × 36.60 = C$ 56,364.00', () => {
    expect(aCordobas(parsear('1,540.00', 'USD'), tasa('36.60'))).toBe(5636400)
  })
  it('redondea la mitad hacia arriba: US$ 0.04 × 36.6250 = 146.5 → 147 centavos', () => {
    expect(aCordobas(usd(4), tasa('36.6250'))).toBe(147)
  })
  it('y se aleja del cero en negativos: -146.5 → -147', () => {
    expect(aCordobas(usd(-4), tasa('36.6250'))).toBe(-147)
  })
  it('usa los 4 decimales del BCN: US$ 0.01 × 36.6243 → 37 centavos', () => {
    expect(aCordobas(usd(1), tasa('36.6243'))).toBe(37)
  })
  it('C$ 36,620.00 ÷ 36.62 = US$ 1,000.00', () => {
    expect(aDolares(parsear('36,620.00', 'NIO'), tasa('36.62'))).toBe(100000)
  })
  it('C$ 100.00 ÷ 36.62 = US$ 2.73', () => {
    expect(aDolares(parsear('100', 'NIO'), tasa('36.62'))).toBe(273)
  })
  it('15 % de C$ 1,000.01 = C$ 150.00, y 15 % de C$ 0.10 = 1.5 → 2 centavos', () => {
    expect(aplicarPorcentaje(nio(100001), porcentaje('15'))).toBe(15000)
    expect(aplicarPorcentaje(nio(10), porcentaje('15'))).toBe(2)
  })
})

describe('formatear', () => {
  it.each([
    { centavos: 7918494, esperado: 'C$ 79,184.94' },
    { centavos: -7906, esperado: '-C$ 79.06' },
    { centavos: 0, esperado: 'C$ 0.00' },
    { centavos: 5, esperado: 'C$ 0.05' },
    { centavos: MAX_CENTAVOS, esperado: 'C$ 999,999,999,999.99' },
  ])('$centavos → "$esperado"', ({ centavos, esperado }) => {
    expect(formatear(nio(centavos), 'NIO')).toBe(esperado)
  })
  it('dólares', () => {
    expect(formatear(usd(154000), 'USD')).toBe('US$ 1,540.00')
  })
})

describe('aceptación: arqueo del 16 de octubre (02-REGLAS-NEGOCIO.md)', () => {
  it('da sobrante de C$ 79.06', () => {
    const tc = tasa('36.60')
    const totalArqueo = sumar(aCordobas(parsear('1,540.00', 'USD'), tc), parsear('22,900.00', 'NIO'))
    const diferencia = restar(totalArqueo, parsear('79,184.94', 'NIO'))
    expect(formatear(totalArqueo, 'NIO')).toBe('C$ 79,264.00')
    expect(formatear(diferencia, 'NIO')).toBe('C$ 79.06')
    expect(comparar(diferencia, nio(0))).toBe(1)
  })
})

describe('tipos (lo verifica tsc, no vitest)', () => {
  it('no deja mezclar monedas ni números sueltos', () => {
    const cordobas = nio(100)
    const dolares = usd(100)
    // @ts-expect-error C$ + US$ no compila
    const mezcla = () => sumar(cordobas, dolares)
    // @ts-expect-error un número suelto no es dinero
    const suelto = () => sumar(cordobas, 100)
    // @ts-expect-error formatear exige la misma moneda del monto
    const mal = () => formatear(cordobas, 'USD')
    expect([mezcla, suelto, mal]).toHaveLength(3)
  })
})

describe('límites y casos de borde (revisión con Claude Code)', () => {
  it('parsear: límites exactos del rango', () => {
    expect(parsear('999,999,999,999.99', 'NIO')).toBe(MAX_CENTAVOS)
    expect(parsear('-999,999,999,999.99', 'NIO')).toBe(-MAX_CENTAVOS)
    expect(() => parsear('-1,000,000,000,000.00', 'NIO')).toThrow(ErrorDinero)
  })
  it('parsear: negativos con miles y un decimal', () => {
    expect(parsear('-1,234.56', 'NIO')).toBe(-123456)
    expect(parsear('1,234.5', 'NIO')).toBe(123450)
  })
  it('parsear: la coma es separador de miles (convención 79,184.94)', () => {
    expect(parsear('1,250', 'NIO')).toBe(125000)
  })
  it.each(['0,001', '+5', '5.', '1,25', '0,5'])('parsear rechaza "%s"', (texto) => {
    expect(() => parsear(texto, 'NIO')).toThrow(ErrorDinero)
  })

  it('desdeBD: rechaza más de 2 decimales, notación científica y fuera de rango', () => {
    expect(() => desdeBD(0.001, 'NIO')).toThrow(ErrorDinero)
    expect(() => desdeBD(1e21, 'NIO')).toThrow(ErrorDinero)
    expect(() => desdeBD('1000000000000.00', 'NIO')).toThrow(ErrorDinero)
  })
  it('desdeBD(aBD(x)) devuelve x', () => {
    for (const c of [0, 5, -5, 7906, -7906, MAX_CENTAVOS, -MAX_CENTAVOS]) {
      expect(desdeBD(aBD(nio(c)), 'NIO')).toBe(c)
    }
  })
  it('aBD: extremos y negativos pequeños', () => {
    expect(aBD(nio(MAX_CENTAVOS))).toBe('999999999999.99')
    expect(aBD(nio(-5))).toBe('-0.05')
  })

  it('aritmética: fuera de rango por abajo y en total', () => {
    expect(() => restar(nio(-MAX_CENTAVOS), nio(1))).toThrow(ErrorDinero)
    expect(() => total('NIO', [nio(MAX_CENTAVOS), nio(1)])).toThrow(ErrorDinero)
  })
  it('total valida cada paso: un acumulado fuera de rango no se "arregla" después', () => {
    const grandes = Array.from({ length: 100 }, () => nio(MAX_CENTAVOS))
    const opuestos = Array.from({ length: 100 }, () => nio(-MAX_CENTAVOS))
    expect(() => total('NIO', [...grandes, nio(1), ...opuestos])).toThrow(ErrorDinero)
  })
  it('sumar con uno y con varios montos; negar, abs y comparar', () => {
    expect(sumar(nio(5))).toBe(5)
    expect(sumar(nio(1), nio(2), nio(3))).toBe(6)
    expect(negar(nio(7906))).toBe(-7906)
    expect(abs(nio(7906))).toBe(7906)
    expect(comparar(nio(2), nio(1))).toBe(1)
  })

  it('aDolares: empate en .5, negativos y montos mínimos', () => {
    expect(aDolares(nio(3), tasa('2'))).toBe(2)
    expect(aDolares(nio(-3), tasa('2'))).toBe(-2)
    expect(aDolares(nio(1), tasa('36.62'))).toBe(0)
  })
  it('aCordobas: lanza si el resultado se sale de rango', () => {
    expect(() => aCordobas(usd(MAX_CENTAVOS), tasa('2'))).toThrow(ErrorDinero)
  })
  it('aplicarPorcentaje: 0 %, 100 %, negativos y USD', () => {
    expect(aplicarPorcentaje(nio(100001), porcentaje('0'))).toBe(0)
    expect(aplicarPorcentaje(nio(100001), porcentaje('100'))).toBe(100001)
    expect(aplicarPorcentaje(nio(-10), porcentaje('15'))).toBe(-2)
    expect(aplicarPorcentaje(usd(10), porcentaje('15'))).toBe(2)
  })
  it('porcentaje y tasa: bordes', () => {
    expect(porcentaje('0')).toBe(0)
    expect(porcentaje('100.00')).toBe(10000)
    expect(porcentaje(15)).toBe(1500)
    expect(() => porcentaje('100.01')).toThrow(ErrorDinero)
    expect(tasa('999999.9999')).toBe(9999999999)
    expect(() => tasa('1000000')).toThrow(ErrorDinero)
    expect(() => tasa('36.')).toThrow(ErrorDinero)
    expect(() => tasa('.5')).toThrow(ErrorDinero)
    expect(() => tasa(1e-7)).toThrow(ErrorDinero)
  })

  it('formatear: dólares negativos y cortes de miles', () => {
    expect(formatear(usd(-7906), 'USD')).toBe('-US$ 79.06')
    expect(formatear(nio(99999), 'NIO')).toBe('C$ 999.99')
    expect(formatear(nio(100000), 'NIO')).toBe('C$ 1,000.00')
    expect(formatear(nio(100000000), 'NIO')).toBe('C$ 1,000,000.00')
  })
})
