#!/usr/bin/env bash
# Levanta PostgreSQL 16 con docker compose y ejecuta en orden los scripts
# del proyecto contra la base proyecto_bd. Aborta ante el primer error.
#
# Uso:
#   ./setup.sh                 carga los datos de prueba de 03_Carga_Datos.sql
#   CARGA=masiva ./setup.sh    carga en su lugar Datos/Carga_Masiva.sql
#
# 03_Carga_Datos.sql y Carga_Masiva.sql son datasets alternativos (ambos
# insertan los catálogos con los mismos ids), por eso se ejecuta uno u otro.
set -euo pipefail

cd "$(dirname "$0")"

DB_NAME="proyecto_bd"
DB_USER="${POSTGRES_USER:-postgres}"
CARGA="${CARGA:-base}"

case "$CARGA" in
  base)   SCRIPT_DATOS="ScriptSQL/03_Carga_Datos.sql" ;;
  masiva) SCRIPT_DATOS="Datos/Carga_Masiva.sql" ;;
  *) echo "!! CARGA debe ser 'base' o 'masiva' (recibido: '$CARGA')" >&2; exit 2 ;;
esac

SCRIPTS=(
  ScriptSQL/01_Creacion_Estructura.sql
  ScriptSQL/02_Restricciones.sql
  "$SCRIPT_DATOS"
  ScriptSQL/05_Indices.sql
  ScriptSQL/06_Seguridad_Roles.sql
  ScriptSQL/07_Funciones_Procedimientos.sql
)

echo ">> Levantando PostgreSQL 16 (docker compose up -d --wait)"
docker compose up -d --wait

for script in "${SCRIPTS[@]}"; do
  echo ">> Ejecutando $script"
  if ! docker compose exec -T db \
      psql -q -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" -f "/proyecto/$script"; then
    echo "!! Falló $script. Se aborta la carga." >&2
    echo "   Para empezar de cero: docker compose down -v && ./setup.sh" >&2
    exit 1
  fi
done

echo ">> Listo. Conectarse con:"
echo "   docker compose exec db psql -U $DB_USER -d $DB_NAME"
