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

## Estado y alcance

El proyecto está funcionalmente completo. Queda **una sola tanda de trabajo
pendiente** (ver "Trabajo pendiente" abajo) y después se cierra con un tag
`v1.0.0`.

**No propongas trabajo fuera de ese alcance.** En particular, quedan
explícitamente afuera: particionamiento de tablas, vistas materializadas,
migraciones versionadas, API o frontend, despliegue en la nube, y soporte para
otros motores de base de datos. Son ideas válidas pero no entran en esta versión.

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

## Trabajo pendiente

Una sola tanda, y después `v1.0.0`.

**Escalar el dataset a volumen realista.** Hoy `generador_datos.py` tiene dos
productos hardcodeados y nunca lee `productos_masivos.csv`, así que el dataset
tiene 48 variantes y 1.002 movimientos. Con ese volumen `Inventario` ocupa una
sola página en disco y los índices no muestran ninguna mejora: el benchmark
documenta casi puros resultados nulos.

Objetivo: conectar los dos generadores y llevar el dataset a una escala parecida a
la de una cadena real.

- 1.000 productos desde el CSV, cruzados con talles y colores
- del orden de 500.000 movimientos y 1.500.000 renglones de detalle
- 8 sucursales y unos 40 empleados (con dos empleados no tiene sentido agrupar
  por empleado en la consulta 3)
- precios plausibles por categoría en pesos argentinos: remeras entre 15.000 y
  40.000, zapatillas entre 80.000 y 250.000, y así según categoría. Hoy salen
  cifras de 138.000 por unidad promedio, que no son creíbles.

Con ese volumen probablemente convenga emitir `COPY` en vez de `INSERT` multifila,
y revisar que el CI no se pase de tiempo.

Después de regenerar hay que re-correr `benchmark.sh`, actualizar la tabla y el
análisis del README con los números reales, y verificar que sigan dando cero
discrepancias de inventario y cero stock negativo.

## Cosas conocidas que no se arreglan

- Las matrículas de los integrantes siguen dentro de dos PDFs versionados y en el
  historial de git. Está documentado y decidido: no se reescribe el historial.
- `generar_masivos.py` no fija semilla de RNG (`generador_datos.py` sí, con 42).
- `Empleados` no tiene relación directa con `Sucursales`: un empleado solo se
  asocia a una sucursal a través de los movimientos que registró. Es una decisión
  discutible y está identificada como tal.

## Nota

Parte del trabajo de este repo se hace con asistencia de Claude Code, bajo
revisión y decisiones de diseño propias. El README lo aclara al pie.
