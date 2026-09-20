#!/usr/bin/env bash
# Levanta PostgreSQL 16 con docker compose y ejecuta en orden los scripts
# del proyecto contra la base proyecto_bd. Aborta ante el primer error.
#
# Uso:
#   ./setup.sh                 carga los datos de prueba de 03_Carga_Datos.sql
#   CARGA=masiva ./setup.sh    carga en su lugar Datos/Carga_Masiva.sql, que
#                              necesita los CSVs de Datos/generado/ (ver abajo)
#   ./setup.sh --reset         recrea la base aunque esté vacía
#
# Es idempotente: si encuentra restos de una corrida anterior recrea la base
# desde cero, así que correrlo dos veces seguidas siempre funciona.
#
# 03_Carga_Datos.sql y Carga_Masiva.sql son datasets alternativos (ambos
# cargan las mismas tablas con ids explícitos desde 1), por eso se ejecuta uno u otro.
set -euo pipefail

cd "$(dirname "$0")"

DB_NAME="proyecto_bd"
DB_USER="${POSTGRES_USER:-postgres}"
CARGA="${CARGA:-base}"
RESET_FORZADO=0

uso() {
  cat <<'AYUDA'
Uso:
  ./setup.sh                 carga los datos de prueba de 03_Carga_Datos.sql
  CARGA=masiva ./setup.sh    carga en su lugar Datos/Carga_Masiva.sql
  ./setup.sh --reset         recrea la base aunque esté vacía

Si encuentra restos de una corrida anterior recrea la base desde cero, así que
correrlo dos veces seguidas siempre funciona.
AYUDA
}

while [ $# -gt 0 ]; do
  case "$1" in
    --reset) RESET_FORZADO=1 ;;
    -h|--help) uso; exit 0 ;;
    *) echo "!! Opción desconocida: '$1'" >&2; uso >&2; exit 2 ;;
  esac
  shift
done

case "$CARGA" in
  base)   SCRIPT_DATOS="ScriptSQL/03_Carga_Datos.sql" ;;
  masiva) SCRIPT_DATOS="Datos/Carga_Masiva.sql" ;;
  *) echo "!! CARGA debe ser 'base' o 'masiva' (recibido: '$CARGA')" >&2; exit 2 ;;
esac

# Los CSVs del dataset masivo no se versionan. Se chequea antes de levantar nada
# para no dejar la base a medio cargar.
if [ "$CARGA" = masiva ] && [ ! -s Datos/generado/inventario.csv ]; then
  echo "!! Faltan los CSVs de Datos/generado/. Generarlos con:" >&2
  echo "   cd Datos && python generar_masivos.py && python generador_datos.py" >&2
  exit 1
fi

SCRIPTS=(
  ScriptSQL/01_Creacion_Estructura.sql
  ScriptSQL/02_Restricciones.sql
  "$SCRIPT_DATOS"
  ScriptSQL/05_Indices.sql
  ScriptSQL/06_Seguridad_Roles.sql
  ScriptSQL/07_Funciones_Procedimientos.sql
)

# Los roles y usuarios de 06 se crean en el cluster, no dentro de la base: un
# DROP DATABASE no los borra y 06 volvería a fallar con "role already exists".
# La lista se lee del propio script para que no se desincronice si se agrega uno.
mapfile -t ROLES_PROYECTO < <(
  grep -oiE 'CREATE[[:space:]]+(ROLE|USER)[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*' \
    ScriptSQL/06_Seguridad_Roles.sql | awk '{print tolower($3)}' | sort -u
)
if [ "${#ROLES_PROYECTO[@]}" -eq 0 ]; then
  echo "!! No pude leer los roles de ScriptSQL/06_Seguridad_Roles.sql" >&2
  exit 1
fi

# Dos formas de la misma lista: entrecomillada para el IN (...) que los busca,
# y pelada para el DROP ROLE, que espera identificadores.
ROLES_SQL=$(printf "'%s'," "${ROLES_PROYECTO[@]}"); ROLES_SQL="${ROLES_SQL%,}"
ROLES_LISTA=$(printf '%s,' "${ROLES_PROYECTO[@]}"); ROLES_LISTA="${ROLES_LISTA%,}"

# psql corre parado en /proyecto/Datos porque los \copy de Carga_Masiva.sql usan
# rutas relativas. Para los demas scripts da igual: se pasan con ruta absoluta.
psql_en() {  # $1 = base a la que conectarse, el resto va tal cual a psql
  local base="$1"; shift
  docker compose exec -T -w /proyecto/Datos db \
    psql -q -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$base" "$@"
}

consultar() {  # $1 = base, $2 = SQL; devuelve el valor pelado
  psql_en "$1" -tA -c "$2" | tr -d '[:space:]'
}

recrear_desde_cero() {
  # WITH (FORCE) corta las sesiones abiertas (pgAdmin, una consola psql olvidada):
  # sin eso el DROP falla con "database is being accessed by other users".
  psql_en postgres -c "DROP DATABASE IF EXISTS $DB_NAME WITH (FORCE)"
  psql_en postgres -c "CREATE DATABASE $DB_NAME"
  # Recién ahora, sin la base que tenía los GRANT, los roles se pueden borrar.
  psql_en postgres -c "DROP ROLE IF EXISTS $ROLES_LISTA"
}

echo ">> Levantando PostgreSQL 16 (docker compose up -d --wait)"
docker compose up -d --wait

# Detección de restos: tablas en el esquema public o roles del proyecto ya creados.
# Alcanza con que haya uno para que la corrida anterior haya dejado algo que
# choca con 01 o con 06.
restos=0
if [ "$(consultar postgres "SELECT count(*) FROM pg_database WHERE datname = '$DB_NAME'")" = 0 ]; then
  restos=1  # la base no existe: hay que crearla igual
elif [ "$(consultar "$DB_NAME" "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")" != 0 ]; then
  restos=1
elif [ "$(consultar postgres "SELECT count(*) FROM pg_roles WHERE rolname IN ($ROLES_SQL)")" != 0 ]; then
  restos=1
fi

if [ "$RESET_FORZADO" -eq 1 ] || [ "$restos" -eq 1 ]; then
  echo ">> Recreando la base $DB_NAME desde cero (se pierden los datos que tenga)"
  recrear_desde_cero
fi

for script in "${SCRIPTS[@]}"; do
  echo ">> Ejecutando $script"
  if ! psql_en "$DB_NAME" -f "/proyecto/$script"; then
    echo "!! Falló $script. Se aborta la carga." >&2
    echo "   Para empezar de cero: ./setup.sh --reset" >&2
    exit 1
  fi
done

echo ">> Listo. Conectarse con:"
echo "   docker compose exec db psql -U $DB_USER -d $DB_NAME"
