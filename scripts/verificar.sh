#!/usr/bin/env bash
# Corre un script de verificación contra la base local y compara la cantidad de ERROR.
# Uso: pnpm db:verificar supabase/verificaciones/<archivo>.sql
set -euo pipefail
archivo="$1"
esperado=$(grep -m1 -oP '(?<=-- esperado: errores=)\d+' "$archivo" || echo "?")
salida=$(docker exec -i supabase_db_cuadra psql -U postgres -v ON_ERROR_STOP=0 < "$archivo" 2>&1)
echo "$salida"
errores=$(grep -c 'ERROR:' <<< "$salida" || true)
echo "----"
echo "Archivo: $archivo"
echo "ERROR encontrados: $errores · esperados: $esperado"
if [[ "$esperado" != "?" && "$errores" != "$esperado" ]]; then
  echo "RESULTADO: NO COINCIDE"
  exit 1
fi
echo "RESULTADO: conteo de errores OK; revisar los valores de cada sección contra su título"
