/**
 * Dominio del conteo de efectivo por denominación (arqueo de caja).
 * TypeScript puro: sin base de datos. Dinero en centavos enteros (ver src/lib/money.ts).
 */
import { ErrorDinero, centavos, nio, usd, type Centavos, type Moneda } from '@/lib/money'

export type TipoDenominacion = 'billete' | 'moneda'

/** Una denominación con su valor en centavos de SU moneda (0.10 = 10). */
export type Denominacion<M extends Moneda = Moneda> = M extends Moneda
  ? { readonly moneda: M; readonly tipo: TipoDenominacion; readonly valor: Centavos<M> }
  : never

export interface LineaConteo {
  denominacion: Denominacion
  cantidad: number
}

export type TotalConteo = { NIO: Centavos<'NIO'>; USD: Centavos<'USD'> }

export class ErrorConteo extends Error {
  constructor(mensaje: string) {
    super(mensaje)
    this.name = 'ErrorConteo'
  }
}

function den<M extends Moneda>(moneda: M, tipo: TipoDenominacion, valor: number): Denominacion {
  return { moneda, tipo, valor: centavos(valor, moneda) } as Denominacion
}

/** Catálogo inicial (18). Debe coincidir con la migración de public.denominaciones. */
export const DENOMINACIONES_POR_DEFECTO: readonly Denominacion[] = [
  ...[100000, 50000, 20000, 10000, 5000, 2000, 1000].map((v) => den('NIO', 'billete', v)),
  ...[500, 100, 50, 25, 10].map((v) => den('NIO', 'moneda', v)),
  ...[10000, 5000, 2000, 1000, 500, 100].map((v) => den('USD', 'billete', v)),
]

const claveDe = (d: Denominacion) => `${d.moneda}:${d.tipo}:${d.valor}`

/**
 * Total en centavos por moneda. C$ y US$ nunca se suman entre sí.
 * Lanza ErrorConteo si una cantidad no es entero >= 0 o si una denominación se repite.
 */
export function totalConteo(lineas: readonly LineaConteo[]): TotalConteo {
  const vistas = new Set<string>()
  const acumulado: Record<Moneda, number> = { NIO: 0, USD: 0 }

  for (const { denominacion, cantidad } of lineas) {
    const clave = claveDe(denominacion)
    if (!Number.isSafeInteger(cantidad) || cantidad < 0) {
      throw new ErrorConteo(`Cantidad inválida para ${clave}: ${cantidad}`)
    }
    if (vistas.has(clave)) {
      throw new ErrorConteo(`Denominación repetida: ${clave}`)
    }
    vistas.add(clave)
    acumulado[denominacion.moneda] += denominacion.valor * cantidad
  }

  try {
    return { NIO: nio(acumulado.NIO), USD: usd(acumulado.USD) }
  } catch (e) {
    if (e instanceof ErrorDinero) throw new ErrorConteo(`Total del conteo fuera de rango: ${e.message}`)
    throw e
  }
}

const PATRON_CODIGO = /^[A-Z0-9]{2,10}$/ // igual al check de sucursales.codigo
const PATRON_FECHA = /^(\d{4})-(\d{2})-(\d{2})$/

/**
 * 'RAMA', 2, '2026-10-16' → 'RAMA-C2-20261016'.
 * La fecha es string 'YYYY-MM-DD', nunca Date: así no hay desfase UTC (Nicaragua es UTC-6).
 */
export function formatearCorrelativo(codigoSucursal: string, numeroCaja: number, fecha: string): string {
  if (!PATRON_CODIGO.test(codigoSucursal)) {
    throw new ErrorConteo(`Código de sucursal inválido: "${codigoSucursal}"`)
  }
  if (!Number.isSafeInteger(numeroCaja) || numeroCaja < 1) {
    throw new ErrorConteo(`Número de caja inválido: ${numeroCaja}`)
  }
  const m = PATRON_FECHA.exec(fecha)
  if (!m) throw new ErrorConteo(`Fecha inválida, se espera YYYY-MM-DD: "${fecha}"`)
  const [anio, mes, dia] = [Number(m[1]), Number(m[2]), Number(m[3])]
  // Calendario real (rechaza 2026-02-30). UTC solo para validar; no se formatea nada desde el Date.
  const prueba = new Date(Date.UTC(anio, mes - 1, dia))
  if (prueba.getUTCFullYear() !== anio || prueba.getUTCMonth() !== mes - 1 || prueba.getUTCDate() !== dia) {
    throw new ErrorConteo(`Fecha inexistente: "${fecha}"`)
  }
  return `${codigoSucursal}-C${numeroCaja}-${m[1]}${m[2]}${m[3]}`
}
