#!/usr/bin/env bash
# Reinicia la base, crea los usuarios de desarrollo y corre TODAS las verificaciones.
# Corre con el seed y los usuarios dev presentes a propósito: prueba que no chocan con las verificaciones.
# Sale con código 1 si alguna falla.
# Uso: pnpm db:verificar-todo
set -uo pipefail
cd "$(dirname "$0")/.."

npx supabase db reset || { echo "FALLA: db reset"; exit 1; }
pnpm db:seed-usuarios || { echo "FALLA: db:seed-usuarios"; exit 1; }

fallas=0
echo
for f in supabase/verificaciones/*.sql; do
  if bash scripts/verificar.sh "$f" > /dev/null 2>&1; then
    echo "OK    $f"
  else
    echo "FALLA $f"
    fallas=$((fallas + 1))
  fi
done
echo
if [[ $fallas -gt 0 ]]; then
  echo "RESULTADO: $fallas verificación(es) con FALLA"
  exit 1
fi
echo "RESULTADO: todas las verificaciones OK"
