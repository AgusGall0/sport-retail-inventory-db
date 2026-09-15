# CLAUDE.md

Contexto permanente para trabajar en este repositorio.

## Qué es este proyecto

Base de datos relacional en PostgreSQL para una cadena de indumentaria deportiva
con múltiples sucursales. Cubre el ciclo completo del inventario: ingreso desde
proveedores, traslados entre sucursales y venta al público, con control de stock
por variante (producto + talle + color).

Nació como proyecto integrador de la cátedra de Base de Datos (Ingeniería en
Informática, Facultad de Tecnología y Cs. Aplicadas, U.N.Ca.) y hoy se mantiene
como pieza de portfolio profesional. Eso define la vara: el repo tiene que poder
levantarse con un comando, correr verde en CI, y que cada decisión de diseño esté
justificada en el README.

## Estado

El proyecto está completo y cerrado en `v1.0.0`. No hay trabajo pendiente. La
última tanda escaló el dataset masivo a volumen realista, re-midió el benchmark
con esos datos y agregó al CI la carga y verificación del dataset masivo.

## Alcance

**No propongas trabajo nuevo.** En particular, quedan explícitamente afuera:
particionamiento de tablas, vistas materializadas, migraciones versionadas, API o
frontend, despliegue en la nube, soporte para otros motores de base de datos, y
todo lo que figura en "Cosas conocidas que no se arreglan". Son ideas válidas
pero no entran en `v1.0.0`.

Si detectás algo que te parece importante y está fuera de alcance, mencionalo en
una línea al final de tu respuesta y seguí. No lo implementes.

## Stack y versiones

- PostgreSQL 16 (imagen `postgres:16`)
- Python 3 con `pandas==2.2.3` y `numpy==2.1.3` (pinneadas también en CI)
- Docker con plugin Compose
- CI en GitHub Actions con `services: postgres:16`

Las versiones están fijas a propósito. No las actualices salvo que te lo pida.

## Estructura

```
docker-compose.yml  PostgreSQL 16 en contenedor, con volumen pgdata persistente
setup.sh            Levanta el contenedor y ejecuta los scripts en orden
ScriptSQL/          Scripts numerados 01 a 08, se ejecutan en orden
Datos/              Generadores en Python y el SQL de carga masiva
Pruebas/            benchmark.sh, verificaciones_ci.sql, casos y evidencias
Documentacion/      Modelo conceptual, diagrama relacional, diseño técnico
.github/workflows/  ci.yml
```

`ScriptSQL/`, `Datos/` y `Pruebas/` se montan de solo lectura en `/proyecto/`
dentro del contenedor.

## Decisiones de diseño ya tomadas

Estas están cerradas. No las revises ni propongas alternativas salvo que
encuentres un error concreto.

**Producto y variante separados.** `Productos` guarda lo conceptual (nombre,
marca, categoría, precio) y `Producto_Variante` cada artículo físico (producto +
talle + color). El stock se lleva a nivel de variante y sucursal.

**El inventario se deriva del historial.** La carga masiva genera un movimiento
de Entrada de apertura por sucursal, fechado el 2024-12-31, y el inventario es el
neto de todos los movimientos. Esto hace el dataset auto-consistente y replayable
por `trg_actualizar_stock_automatico`. La verificación de cero discrepancias entre
`Inventario` y el neto recalculado es innegociable: si un cambio la rompe, el
cambio está mal.

**La lógica de negocio vive en la base**, no en la aplicación: triggers para
actualizar stock, validar disponibilidad y autocompletar precios.

**Tres roles bajo mínimo privilegio** más dos vistas para acceso de solo lectura.

**La base es desechable.** `docker compose down -v && ./setup.sh` reconstruye todo
desde cero en segundos. Esa propiedad es lo que hace posible el benchmark y el CI.

**El benchmark usa quince repeticiones** por consulta. Con tres, el ruido era del
tamaño de la señal.

**No se versionan los datos generados.** El generador es la fuente de verdad y
con semilla fija su salida es determinista, así que versionar el archivo derivado
no aporta nada y traería un blob de cientos de MB al repo. Los CSVs se generan en
`Datos/generado/` (ignorado por git) y `Carga_Masiva.sql` es un script chico que
los carga con `\copy`. El camino por defecto (`./setup.sh` sin `CARGA=masiva`)
sigue siendo puro SQL y no requiere Python.

**Escala del dataset masivo.** 500.008 movimientos (500.000 del historial más una
apertura por sucursal), 1.649.014 renglones de detalle, 18.632 variantes de 1.000
productos, 8 sucursales y 40 empleados (cinco por sucursal, asignados solo dentro
del generador). Es la escala a la que `Inventario` ocupa 806 páginas y los índices
tienen algo que medir: con el dataset anterior (1.002 movimientos, 48 variantes)
el benchmark daba casi puros resultados nulos. Los parámetros son constantes al
principio de `generador_datos.py`; si cambian, hay que re-correr el benchmark y
actualizar el README.

**Talles según la categoría.** Ropa de S a XXL, zapatillas de 39 a 44 y medias
talle único, cruzados con cuatro colores. El esquema no lo restringe porque no hay
una tabla de talles válidos por categoría: lo resuelve el generador por convención
con `TALLES_POR_CATEGORIA`. Es una limitación del modelo, no del generador, y así
está documentada en el README.

**Popularidad Zipf-Mandelbrot.** Cada producto recibe un puesto al azar y pesa
1 / (puesto + 20); dentro del producto, además, pesan el talle y el color. Así se
venden los productos en un retail real: los cien más vendidos suman el 45 % de las
unidades y queda una cola larga que casi no se vende. Con Zipf puro, sin el
desplazamiento, un solo producto se llevaba el 13 % de las ventas, y eso no es
creíble. Con popularidad uniforme la consulta 2 devuelve cero filas. El argumento
tiene un límite: un control con popularidad uniforme dio los mismos diez planes,
así que en este benchmark el sesgo cambia los resultados y no las decisiones del
planificador. No afirmes lo contrario sin medirlo.

**Fecha fija de fin del historial.** Los movimientos van del 2025-01-01 al
2026-09-14 (`FECHA_FIN_HISTORIAL`), no hasta `datetime.now()`: con la fecha actual
dos corridas daban fechas distintas y el generador no era determinista. La
contracara es que las consultas 1 y 2 usan `CURRENT_DATE`, así que sus filas y
tiempos dependen del día en que se ejecutan. Los números del README corresponden a
la medición del 14 de septiembre de 2026.

## Convenciones

**Idioma:** todo en español. Nombres de tablas, columnas, funciones, comentarios,
mensajes de commit y documentación.

**Nombres:** tablas en plural y capitalizadas (`Movimientos`,
`Detalle_Movimientos`), funciones con prefijo `fn_`, procedimientos `sp_`,
triggers `trg_`, índices `idx_`.

**Mensajes de commit:** primera persona del singular, presente, en español.
Ejemplos reales del historial: "Agrego Pruebas/benchmark.sh para medir las
consultas de forma reproducible", "Re-mido el rendimiento con benchmark.sh y
actualizo el README", "Renombro Capturas_Etapa_III a Etapa_III: es un PDF, no
capturas". Describí qué cambió y por qué, no en qué tarea estabas.

**Ramas:** una por unidad de trabajo, con prefijo (`feat/`, `fix/`, `chore/`).
Un commit por cambio lógico, no uno gigante al final.

**Sin números mágicos:** los parámetros del generador de datos van como
constantes nombradas arriba del archivo, no incrustados en el código.

## Reglas de trabajo

**No inventes números.** Cualquier cifra que aparezca en el README (tiempos,
cantidades de filas, porcentajes de mejora) tiene que venir de una corrida real
que hayas ejecutado. Si no podés correrla, decilo y no toques la tabla.

**No reescribas el README completo.** Está bien escrito y quiero conservar su voz.
Hacé ediciones quirúrgicas y mostrame el `git diff` antes de commitear.

**Preguntá en vez de asumir.** Si una decisión tiene más de un camino razonable,
frená, explicame las opciones con sus trade-offs, y esperá. Especialmente en
cualquier cosa que toque el modelo de datos o la coherencia del dataset.

**Verificá antes de afirmar.** Si vas a decir que algo falla, reproducí el fallo.
Si vas a decir que algo funciona, corrélo.

**El README no puede describir algo que el código no hace.** Si arreglás un
comportamiento, actualizá el texto. Si decidimos no arreglarlo, actualizá el texto
igual para que refleje la realidad.

**No toques** `docker-compose.override.yml` (es configuración local mía, está en
`.gitignore`) ni los PDFs de `Documentacion/`.

**No borres** los archivos de planes en `Pruebas/Evidencias_Rendimiento/` sin
regenerarlos.

## Cosas conocidas que no se arreglan

- Las matrículas de los integrantes siguen dentro de dos PDFs versionados y en el
  historial de git. Está documentado y decidido: no se reescribe el historial.
- `Empleados` no tiene relación directa con `Sucursales`: un empleado solo se
  asocia a una sucursal a través de los movimientos que registró. Es una decisión
  discutible y está identificada como tal.
- Los triggers de `07_Funciones_Procedimientos.sql` emiten varios `RAISE NOTICE`
  por cada renglón de detalle. Es discutible: sirven para seguir en pgAdmin qué
  hace el trigger en una venta suelta, pero reproducir el dataset masivo a
  través de los triggers generaría millones de avisos y sería mucho más lento.
  La carga masiva no pasa por ellos porque corre antes de `07`.
- `08_Concurrencia.sql` asume las cantidades del dataset chico: registra dos
  ventas de 7 unidades de la variante 1 en la sucursal 1. En el dataset masivo
  esa celda tiene menos stock y `trg_validar_stock_antes_insertar` rechaza la
  segunda venta, así que el script falla. Eso significa que la concurrencia
  solo se prueba contra `03_Carga_Datos.sql`, en el job de la carga base del CI.
- Las consultas 2 y 3 de `04_Consultas_Reportes.sql` filtran el año con
  `EXTRACT(YEAR FROM fecha_hora)`, una expresión sin estadísticas: sobre el
  dataset masivo el planificador estima 777 filas por worker contra 51.613 y
  73.250 reales, y el índice sobre `fecha_hora` no se puede usar. Se resolvería
  con un índice sobre la expresión o reescribiendo el filtro como rango de
  fechas (`fecha_hora >= '2025-01-01' AND fecha_hora < '2026-01-01'`). Queda
  fuera de alcance de v1.0.0; está documentado en el análisis de Rendimiento
  del README.

## Nota

Parte del trabajo de este repo se hace con asistencia de Claude Code, bajo
revisión y decisiones de diseño propias. El README lo aclara al pie.
