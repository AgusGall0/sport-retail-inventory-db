#!/usr/bin/env bash
# Mide las consultas de ScriptSQL/04_Consultas_Reportes.sql con y sin los
# indices de ScriptSQL/05_Indices.sql, y deja los planes completos en
# Pruebas/Evidencias_Rendimiento/.
#
# Uso:
#   Pruebas/benchmark.sh
#
# ATENCION: levanta la base desde cero. Hace "docker compose down -v", asi que
# BORRA el volumen de datos y todo lo que hubiera cargado.
#
# Sobre la idempotencia: cada corrida parte del mismo volumen vacio y carga el
# mismo Carga_Masiva.sql, asi que los planes, las filas devueltas y los indices
# elegidos por el planificador son identicos entre corridas. Los milisegundos
# no: son una medicion. Por eso de cada consulta se toma la corrida mas rapida.
#
# Con este volumen las consultas tardan menos de un milisegundo y el ruido de
# medicion es del mismo orden que la diferencia que se quiere medir: con tres
# repeticiones se vieron oscilaciones de 0,58 a 1,17 ms para la misma consulta
# con el mismo plan. Subir las repeticiones ajusta el minimo y estabiliza la
# comparacion, a costa de que la corrida tarde mas:
#
#   REPETICIONES=15 Pruebas/benchmark.sh
#
# La base se carga con 01, 02 y el dataset masivo, y NADA MAS. Se saltean a
# proposito 06_Seguridad_Roles.sql y 07_Funciones_Procedimientos.sql: crean
# roles y triggers que no intervienen en un SELECT y solo agregan ruido y
# modos de falla. 05_Indices.sql es justamente la variable del experimento.
set -euo pipefail

cd "$(dirname "$0")/.."

DB_NAME="proyecto_bd"
DB_USER="${POSTGRES_USER:-postgres}"
REPETICIONES="${REPETICIONES:-3}"
DIR_SALIDA="Pruebas/Evidencias_Rendimiento"
SCRIPT_CONSULTAS="ScriptSQL/04_Consultas_Reportes.sql"
SCRIPT_INDICES="ScriptSQL/05_Indices.sql"

# Etiquetas para la tabla resumen, en el orden en que aparecen las consultas
# dentro de 04_Consultas_Reportes.sql.
ETIQUETAS=(
  "Recaudación por marca, salidas del último trimestre"
  "Variantes sin salidas en el año"
  "Tickets y recaudación por empleado en Sucursal NOA"
  "Variantes con stock bajo"
  "Ventas por marca y sucursal"
)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Envoltorio del psql del contenedor. -X ignora el .psqlrc del usuario, para
# que una configuracion personal no cambie el formato de la salida.
psql_db() {
  docker compose exec -T db \
    psql -X -q -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" "$@"
}

# ---------------------------------------------------------------------------
# 1. Base desde cero
# ---------------------------------------------------------------------------
echo ">> Levantando PostgreSQL desde cero (se borra el volumen)"
docker compose down -v >/dev/null 2>&1 || true
docker compose up -d --wait >/dev/null

for script in ScriptSQL/01_Creacion_Estructura.sql \
              ScriptSQL/02_Restricciones.sql \
              Datos/Carga_Masiva.sql; do
  echo ">> Cargando $script"
  psql_db -f "/proyecto/$script" >/dev/null
done

VERSION_PG="$(psql_db -t -A -c "SHOW server_version")"
FILAS_MOV="$(psql_db -t -A -c "SELECT count(*) FROM Movimientos")"
FILAS_DET="$(psql_db -t -A -c "SELECT count(*) FROM Detalle_Movimientos")"
FILAS_INV="$(psql_db -t -A -c "SELECT count(*) FROM Inventario")"
FILAS_VAR="$(psql_db -t -A -c "SELECT count(*) FROM Producto_Variante")"
FILAS_SAL="$(psql_db -t -A -c "SELECT count(*) FROM Movimientos WHERE tipo_movimiento='Salida'")"
DATASET="$FILAS_MOV movimientos, $FILAS_DET detalles, $FILAS_VAR variantes, $FILAS_SAL salidas, $FILAS_INV filas de inventario"
echo ">> PostgreSQL $VERSION_PG — $DATASET"

# ---------------------------------------------------------------------------
# 2. Separar las consultas de 04 en archivos sueltos
# ---------------------------------------------------------------------------
# Se quitan los comentarios de linea y se corta en cada ';' final.
awk -v dir="$TMP" '
  { linea = $0; sub(/--.*/, "", linea); buf = buf linea "\n"
    if (linea ~ /;[[:space:]]*$/) {
      prueba = buf; gsub(/[[:space:];\n]/, "", prueba)
      if (prueba != "") { n++; printf "%s", buf > (dir "/q" n ".sql"); close(dir "/q" n ".sql") }
      buf = "" } }
' "$SCRIPT_CONSULTAS"

CANTIDAD_CONSULTAS="$(find "$TMP" -maxdepth 1 -name 'q*.sql' | wc -l)"
if [ "$CANTIDAD_CONSULTAS" -eq 0 ]; then
  echo "!! No se pudo extraer ninguna consulta de $SCRIPT_CONSULTAS" >&2
  exit 1
fi
echo ">> $CANTIDAD_CONSULTAS consultas extraidas de $SCRIPT_CONSULTAS"

# 05_Indices.sql mezcla EXPLAIN ANALYZE con CREATE INDEX; aca solo interesan
# las creaciones.
awk '/^CREATE INDEX/,/;/' "$SCRIPT_INDICES" > "$TMP/indices.sql"
CANTIDAD_INDICES="$(grep -c '^CREATE INDEX' "$TMP/indices.sql")"
echo ">> $CANTIDAD_INDICES indices extraidos de $SCRIPT_INDICES"

mkdir -p "$DIR_SALIDA"

# ---------------------------------------------------------------------------
# 3. Medicion
# ---------------------------------------------------------------------------
# medir <numero> <sufijo> <descripcion del escenario>
# Corre la consulta REPETICIONES veces, se queda con la de menor tiempo de
# ejecucion y escribe el plan completo de esa corrida.
medir() {
  local n="$1" sufijo="$2" escenario="$3"
  local consulta="$TMP/q${n}.sql"
  local mejor_tiempo="" mejor_plan="" tiempos=""

  printf 'EXPLAIN (ANALYZE, BUFFERS)\n' > "$TMP/explain.sql"
  cat "$consulta" >> "$TMP/explain.sql"

  for r in $(seq 1 "$REPETICIONES"); do
    psql_db -f /dev/stdin < "$TMP/explain.sql" > "$TMP/plan_${r}.txt" 2>&1
    local t
    t="$(grep -oE 'Execution Time: [0-9.]+' "$TMP/plan_${r}.txt" | tail -1 | grep -oE '[0-9.]+' || true)"
    if [ -z "$t" ]; then
      echo "!! La consulta $n no devolvio tiempo de ejecucion. Salida:" >&2
      cat "$TMP/plan_${r}.txt" >&2
      exit 1
    fi
    tiempos="${tiempos:+$tiempos / }$t"
    if [ -z "$mejor_tiempo" ] || awk "BEGIN{exit !($t < $mejor_tiempo)}"; then
      mejor_tiempo="$t"; mejor_plan="$TMP/plan_${r}.txt"
    fi
  done

  # Cuantas filas devuelve realmente la consulta (sin el EXPLAIN adelante).
  local filas
  filas="$(sed 's/;[[:space:]]*$//' "$consulta" \
    | { printf 'SELECT count(*) FROM (\n'; cat; printf '\n) AS resultado;\n'; } \
    | psql_db -t -A -f /dev/stdin)"

  # Indices propios del proyecto que el planificador realmente eligio.
  local usados
  usados="$(grep -oE 'idx_[a-z_]+' "$mejor_plan" | sort -u | paste -sd ', ' - || true)"
  [ -z "$usados" ] && usados="ninguno"

  {
    printf 'Consulta %s — %s\n' "$n" "${ETIQUETAS[$((n-1))]}"
    printf 'Escenario: %s\n' "$escenario"
    printf 'PostgreSQL: %s\n' "$VERSION_PG"
    printf 'Dataset: Datos/Carga_Masiva.sql — %s\n' "$DATASET"
    printf 'Repeticiones: %s — tiempos de ejecución: %s ms — mejor: %s ms\n' \
      "$REPETICIONES" "$tiempos" "$mejor_tiempo"
    printf 'Filas devueltas: %s\n' "$filas"
    printf 'Índices del proyecto usados por el planificador: %s\n' "$usados"
    printf '\n--- SQL ---\n'
    cat "$consulta"
    printf '\n--- EXPLAIN (ANALYZE, BUFFERS) de la mejor de las %s corridas ---\n' "$REPETICIONES"
    cat "$mejor_plan"
  } > "$DIR_SALIDA/q${n}_${sufijo}.txt"

  # Se devuelven por archivo para armar el resumen despues.
  printf '%s\t%s\t%s\t%s\n' "$n" "$mejor_tiempo" "$filas" "$usados" >> "$TMP/resumen_${sufijo}.tsv"
}

echo ">> Escenario 1/2: sin índices"
psql_db -c "ANALYZE;" >/dev/null
for n in $(seq 1 "$CANTIDAD_CONSULTAS"); do
  echo "   consulta $n"
  medir "$n" "sin_indices" "sin índices (05_Indices.sql no aplicado)"
done

echo ">> Aplicando los $CANTIDAD_INDICES índices de $SCRIPT_INDICES"
psql_db -f /dev/stdin < "$TMP/indices.sql" >/dev/null
psql_db -c "ANALYZE;" >/dev/null

echo ">> Escenario 2/2: con índices"
for n in $(seq 1 "$CANTIDAD_CONSULTAS"); do
  echo "   consulta $n"
  medir "$n" "con_indices" "con los $CANTIDAD_INDICES índices de 05_Indices.sql aplicados"
done

# ---------------------------------------------------------------------------
# 4. Resumen en markdown
# ---------------------------------------------------------------------------
echo
echo "Entorno: PostgreSQL $VERSION_PG en Docker, dataset de Datos/Carga_Masiva.sql"
echo "($DATASET), mejor de $REPETICIONES corridas por consulta."
echo
echo "| # | Consulta | Filas | Sin índices (ms) | Con índices (ms) | Mejora | Índice nuevo que usó el planificador |"
echo "|---|---|---|---|---|---|---|"
for n in $(seq 1 "$CANTIDAD_CONSULTAS"); do
  sin="$(awk -F'\t' -v n="$n" '$1==n{print $2}' "$TMP/resumen_sin_indices.tsv")"
  con="$(awk -F'\t' -v n="$n" '$1==n{print $2}' "$TMP/resumen_con_indices.tsv")"
  filas="$(awk -F'\t' -v n="$n" '$1==n{print $3}' "$TMP/resumen_con_indices.tsv")"
  usados="$(awk -F'\t' -v n="$n" '$1==n{print $4}' "$TMP/resumen_con_indices.tsv")"
  mejora="$(awk -v a="$sin" -v b="$con" 'BEGIN{printf "%+.0f %%", (a-b)/a*100}')"
  if [ "$usados" = "ninguno" ]; then
    usados="ninguno, sigue con Seq Scan"
  else
    usados="\`${usados//, /\`, \`}\`"
  fi
  printf '| %s | %s | %s | %s | %s | %s | %s |\n' \
    "$n" "${ETIQUETAS[$((n-1))]}" "$filas" "$sin" "$con" "$mejora" "$usados"
done
echo
echo ">> Planes completos en $DIR_SALIDA/"
