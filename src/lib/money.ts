/**
 * Dinero en Cuadra: siempre centavos enteros, nunca floats.
 * - BD numeric(14,2): se lee con desdeBD() y se escribe con aBD() (como texto).
 * - La moneda va en el tipo: sumar C$ con US$ no compila.
 * - Redondeo: mitad hacia arriba alejándose del cero (igual que REDONDEAR de Excel).
 * - Límite conocido: sumar<Moneda>(...) con el tipo escrito a mano permite mezclar monedas.
 *   Nunca declares variables como Centavos<Moneda>; solo aBD y esCero lo aceptan.
 */

export type Moneda = 'NIO' | 'USD'

declare const marcaMoneda: unique symbol
declare const marcaTasa: unique symbol
declare const marcaPorcentaje: unique symbol

/** Centavos enteros de una moneda. 7918494 = 79,184.94 */
export type Centavos<M extends Moneda> = number & { readonly [marcaMoneda]: M }
/** Tipo de cambio en diezmilésimas. 36.6243 = 366243 */
export type Tasa = number & { readonly [marcaTasa]: true }
/** Porcentaje en centésimas de punto. 15.00 % = 1500 */
export type Porcentaje = number & { readonly [marcaPorcentaje]: true }

/** Máximo de numeric(14,2): 999,999,999,999.99 */
export const MAX_CENTAVOS = 99_999_999_999_999

const SIMBOLO: Record<Moneda, string> = { NIO: 'C$', USD: 'US$' }

// BigInt(n) en lugar de literales como 100n: el tsconfig de Next apunta a ES2017.
const B0 = BigInt(0)
const B1 = BigInt(1)
const B2 = BigInt(2)
const B100 = BigInt(100)
const ESCALA_TASA = BigInt(10_000)
const ESCALA_PORCENTAJE = BigInt(10_000) // 100.00 % = 10000

export class ErrorDinero extends Error {
  constructor(mensaje: string) {
    super(mensaje)
    this.name = 'ErrorDinero'
  }
}

// ---------- construcción ----------

function validar<M extends Moneda>(n: number, moneda?: M): Centavos<M> {
  const donde = moneda ? ` (${moneda})` : ''
  if (!Number.isSafeInteger(n)) {
    throw new ErrorDinero(`No es un entero de centavos${donde}: ${n}`)
  }
  if (Math.abs(n) > MAX_CENTAVOS) {
    throw new ErrorDinero(`Monto fuera de rango${donde}: ${n}`)
  }
  return (n === 0 ? 0 : n) as Centavos<M> // normaliza -0 a 0
}

export function centavos<M extends Moneda>(n: number, moneda: M): Centavos<M> {
  return validar(n, moneda)
}

export const nio = (n: number): Centavos<'NIO'> => centavos(n, 'NIO')
export const usd = (n: number): Centavos<'USD'> => centavos(n, 'USD')

// Acepta "79,184.94", "79184.94", "1540", "-79.06". Máximo 2 decimales.
const PATRON_MONTO = /^(-)?([1-9]\d{0,2}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?$/

function textoACentavos(texto: string): number {
  const m = PATRON_MONTO.exec(texto.trim())
  if (!m) throw new ErrorDinero(`Monto inválido: "${texto}"`)
  const negativo = m[1] === '-'
  const entero = (m[2] ?? '').replaceAll(',', '')
  const decimales = (m[3] ?? '').padEnd(2, '0')
  // BigInt: un texto largo no pierde precisión antes de validar el rango
  const valor = BigInt(entero) * B100 + BigInt(decimales)
  if (valor > BigInt(MAX_CENTAVOS)) {
    throw new ErrorDinero(`Monto fuera de rango: "${texto}"`)
  }
  const n = Number(valor)
  return negativo ? -n : n
}

/** Texto que escribe el usuario → centavos. */
export function parsear<M extends Moneda>(texto: string, moneda: M): Centavos<M> {
  return validar(textoACentavos(texto), moneda)
}

/**
 * Valor numeric que devuelve Supabase (string o number) → centavos.
 * Pasa por texto: String(79184.94) es "79184.94" exacto; 79184.94 * 100 no lo es.
 */
export function desdeBD<M extends Moneda>(valor: string | number, moneda: M): Centavos<M> {
  return validar(textoACentavos(String(valor)), moneda)
}

// ---------- salida ----------

function partes(monto: number) {
  const digitos = String(Math.abs(monto)).padStart(3, '0')
  return {
    signo: monto < 0 ? '-' : '',
    entero: digitos.slice(0, -2),
    decimales: digitos.slice(-2),
  }
}

/** Centavos → texto para numeric(14,2). Se envía como string para no pasar por float. */
export function aBD(monto: Centavos<Moneda>): string {
  const { signo, entero, decimales } = partes(monto)
  return `${signo}${entero}.${decimales}`
}

/** "C$ 79,184.94", "US$ 1,540.00", "-C$ 79.06". Sin Intl: mismo resultado en Node y navegador. */
export function formatear<M extends Moneda>(monto: Centavos<M>, moneda: NoInfer<M>): string {
  const { signo, entero, decimales } = partes(monto)
  const conMiles = entero.replace(/\B(?=(\d{3})+(?!\d))/g, ',')
  return `${signo}${SIMBOLO[moneda]} ${conMiles}.${decimales}`
}

// ---------- aritmética (misma moneda) ----------
// NoInfer: la moneda se deduce SOLO del primer argumento; el resto debe coincidir.

export function sumar<M extends Moneda>(
  primero: Centavos<M>,
  ...resto: Centavos<NoInfer<M>>[]
): Centavos<M> {
  return resto.reduce<Centavos<M>>((acc, m) => validar<M>(acc + m), primero)
}

export function total<M extends Moneda>(
  moneda: M,
  montos: readonly Centavos<NoInfer<M>>[],
): Centavos<M> {
  return montos.reduce<Centavos<M>>((acc, m) => validar<M>(acc + m), validar(0, moneda))
}

export function restar<M extends Moneda>(a: Centavos<M>, b: Centavos<NoInfer<M>>): Centavos<M> {
  return validar<M>(a - b)
}

export function negar<M extends Moneda>(monto: Centavos<M>): Centavos<M> {
  return validar<M>(-monto)
}

export function abs<M extends Moneda>(monto: Centavos<M>): Centavos<M> {
  return validar<M>(Math.abs(monto))
}

export function comparar<M extends Moneda>(a: Centavos<M>, b: Centavos<NoInfer<M>>): -1 | 0 | 1 {
  if (a < b) return -1
  if (a > b) return 1
  return 0
}

export function esCero(monto: Centavos<Moneda>): boolean {
  return monto === 0
}

// ---------- tasas, porcentajes y conversión ----------

/** División entera redondeando la mitad hacia arriba, alejándose del cero (REDONDEAR de Excel). */
function dividirRedondeando(numerador: bigint, divisor: bigint): bigint {
  const negativo = numerador < B0
  const absoluto = negativo ? -numerador : numerador
  const cociente = absoluto / divisor
  const resto = absoluto % divisor
  const redondeado = resto * B2 >= divisor ? cociente + B1 : cociente
  return negativo ? -redondeado : redondeado
}

const PATRON_TASA = /^(\d{1,6})(?:\.(\d{1,4}))?$/

/** "36.60", 36.6243 → Tasa. El BCN publica 4 decimales. */
export function tasa(valor: string | number): Tasa {
  const m = PATRON_TASA.exec(String(valor).trim())
  if (!m) throw new ErrorDinero(`Tipo de cambio inválido: "${valor}"`)
  const n = Number(m[1] ?? '0') * 10_000 + Number((m[2] ?? '').padEnd(4, '0'))
  if (n <= 0) throw new ErrorDinero(`El tipo de cambio debe ser mayor que cero: "${valor}"`)
  return n as Tasa
}

const PATRON_PORCENTAJE = /^(\d{1,3})(?:\.(\d{1,2}))?$/

/** "15", "15.5" → Porcentaje (0 a 100). */
export function porcentaje(valor: string | number): Porcentaje {
  const m = PATRON_PORCENTAJE.exec(String(valor).trim())
  if (!m) throw new ErrorDinero(`Porcentaje inválido: "${valor}"`)
  const n = Number(m[1] ?? '0') * 100 + Number((m[2] ?? '').padEnd(2, '0'))
  if (n > 10_000) throw new ErrorDinero(`Porcentaje mayor que 100: "${valor}"`)
  return n as Porcentaje
}

// BigInt porque centavos × tasa puede pasar de 10^20 y number pierde precisión arriba de 9×10^15.

/** US$ → C$ */
export function aCordobas(monto: Centavos<'USD'>, tc: Tasa): Centavos<'NIO'> {
  return validar(Number(dividirRedondeando(BigInt(monto) * BigInt(tc), ESCALA_TASA)), 'NIO')
}

/** C$ → US$ */
export function aDolares(monto: Centavos<'NIO'>, tc: Tasa): Centavos<'USD'> {
  return validar(Number(dividirRedondeando(BigInt(monto) * ESCALA_TASA, BigInt(tc))), 'USD')
}

export function aplicarPorcentaje<M extends Moneda>(monto: Centavos<M>, pct: Porcentaje): Centavos<M> {
  return validar<M>(Number(dividirRedondeando(BigInt(monto) * BigInt(pct), ESCALA_PORCENTAJE)))
}
