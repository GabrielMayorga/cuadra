@AGENTS.md

# Cuadra by Nuvix

Sistema web multisucursal de contabilidad y administración (arqueo de caja, ingresos y gastos, cuentas por cobrar, proveedores, planilla, reportes). Producto de Nuvix, licenciado a negocios. Las reglas de negocio viven en el Proyecto de Claude "Cuadra by Nuvix" (02-REGLAS-NEGOCIO.md); si una tarea las necesita, pídelas a Gabriel.

## Stack
- Next.js (App Router, carpeta src/), TypeScript, Tailwind
- Supabase local con Docker (Postgres + Auth + RLS)
- Vitest para pruebas
- pnpm, Node 24 (ver .nvmrc)

## Comandos
- pnpm dev, pnpm build
- pnpm test, pnpm typecheck
- pnpm db:start, db:stop, db:reset, db:status
- `pnpm db:verificar-todo`: db reset + usuarios de desarrollo + todas las verificaciones de supabase/verificaciones/ (OK/FALLA por archivo; sale con código 1 si alguna falla)
- Datos de desarrollo: `pnpm db:reset` (migraciones + supabase/seed.sql: empresa, negocios, sucursales, cajas, módulos) y luego `pnpm db:seed-usuarios` (5 usuarios `<rol>@dev.cuadra.test`, uno por rol: dueno, contador, admin, encargado, cajero; contraseña `cuadra-dev-1234`). Requiere `.env.local` con NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY (valores de `pnpm db:status`). Tras cada reset hay que volver a correr db:seed-usuarios.

## Reglas
- Convención de datos de prueba (nunca mezclar): el seed y los usuarios de desarrollo usan UUIDs con prefijo `de000000-` y correos `<rol>@dev.cuadra.test`; las verificaciones de supabase/verificaciones/ usan UUIDs con prefijo `00000000-` y correos `@example.test`. Así las verificaciones corren sobre la base sembrada sin chocar.
- Dinero en centavos enteros, nunca floats. Se usa src/lib/money.ts (se crea en la Fase 1).
- La llave de servicio de Supabase nunca lleva prefijo NEXT_PUBLIC_.
- Commits en español con Conventional Commits.

## Forma de trabajo
- Los commits sí se hacen: uno por pieza y solo cuando la verificación pasa. El push NUNCA se hace sin que Gabriel lo pida.
- Antes de editar archivos, explica el plan y espera confirmación.
- Si ves un error, un riesgo o una decisión débil, dilo antes de ejecutarlo y propón una alternativa.
- Si algo es ambiguo, pregunta antes de suponer.
