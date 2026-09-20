# Proyecto Integrador BD — Gestión de stock para retail deportivo
[![CI](https://github.com/AgusGall0/sport-retail-inventory-db/actions/workflows/ci.yml/badge.svg)](https://github.com/AgusGall0/sport-retail-inventory-db/actions/workflows/ci.yml)

Base de datos relacional en **PostgreSQL** para una cadena de indumentaria deportiva con múltiples sucursales. Cubre el ciclo completo del inventario: ingreso de mercadería desde proveedores, traslados entre sucursales y venta al público, con control de stock por variante (producto + talle + color).

Proyecto integrador de la cátedra de Base de Datos — Ingeniería en Informática, Facultad de Tecnología y Cs. Aplicadas, U.N.Ca.

---

## Modelo de datos

Doce tablas normalizadas hasta 3FN:

```mermaid
erDiagram
    Categorias ||--o{ Productos : clasifica
    Marcas ||--o{ Productos : fabrica
    Productos ||--o{ Producto_Variante : "se declina en"
    Talles ||--o{ Producto_Variante : dimensiona
    Colores ||--o{ Producto_Variante : dimensiona
    Sucursales ||--o{ Inventario : almacena
    Producto_Variante ||--o{ Inventario : "tiene stock en"
    Empleados ||--o{ Movimientos : registra
    Sucursales |o--o{ Movimientos : "es origen de"
    Sucursales |o--o{ Movimientos : "es destino de"
    Proveedores |o--o{ Movimientos : abastece
    Movimientos ||--o{ Detalle_Movimientos : "se detalla en"
    Producto_Variante ||--o{ Detalle_Movimientos : "aparece en"

    Categorias {
        serial id_categoria PK
        varchar nombre UK
        text descripcion
    }
    Marcas {
        serial id_marca PK
        varchar nombre UK
    }
    Talles {
        serial id_talle PK
        varchar nomenclatura UK
    }
    Colores {
        serial id_color PK
        varchar nombre_color UK
    }
    Proveedores {
        serial id_proveedor PK
        varchar razon_social
        varchar cuit UK
        varchar telefono
        varchar email
    }
    Sucursales {
        serial id_sucursal PK
        varchar nombre
        varchar direccion
        varchar ciudad
    }
    Empleados {
        serial id_empleado PK
        varchar documento UK
        varchar nombre
        varchar apellido
        varchar perfil_acceso "CHECK Administrador|Operativo|Consulta"
    }
    Productos {
        serial id_producto PK
        varchar nombre
        text descripcion
        decimal precio_venta_actual "CHECK mayor a 0"
        int id_marca FK
        int id_categoria FK
    }
    Producto_Variante {
        serial id_variante PK
        varchar codigo_barras UK
        int id_producto FK
        int id_talle FK
        int id_color FK
    }
    Inventario {
        int id_sucursal PK, FK
        int id_variante PK, FK
        int cantidad_disponible "CHECK mayor o igual a 0"
    }
    Movimientos {
        serial id_movimiento PK
        timestamp fecha_hora
        varchar tipo_movimiento "CHECK Entrada|Salida|Traslado"
        text observaciones
        int id_sucursal_origen FK "nullable"
        int id_sucursal_destino FK "nullable"
        int id_empleado FK
        int id_proveedor FK "nullable"
    }
    Detalle_Movimientos {
        serial id_detalle PK
        int cantidad "CHECK mayor a 0"
        decimal precio_unitario "CHECK mayor o igual a 0"
        int id_movimiento FK
        int id_variante FK
    }
```

| Grupo | Tablas |
|---|---|
| Catálogos | `Categorias`, `Marcas`, `Talles`, `Colores` |
| Organización | `Proveedores`, `Sucursales`, `Empleados` |
| Producto | `Productos`, `Producto_Variante` |
| Operación | `Inventario`, `Movimientos`, `Detalle_Movimientos` |

La decisión central del diseño es la separación entre **producto** y **variante**. En indumentaria, una misma remera existe en varias combinaciones de talle y color, y cada combinación tiene su propio stock. `Productos` guarda lo conceptual (nombre, descripción, marca, categoría, precio) y `Producto_Variante` cada artículo físico concreto. `Inventario` se lleva a nivel de variante y sucursal, lo que permite saber exactamente qué hay disponible y dónde.

El esquema no restringe qué talles aplican a qué categoría: nada impide registrar una remera talle 42 o unas zapatillas talle S. En un sistema real haría falta una tabla de talles válidos por categoría; acá el generador de datos lo resuelve por convención (`TALLES_POR_CATEGORIA` en `Datos/generador_datos.py`). Es una limitación identificada del modelo, no del generador.

Los movimientos (entrada, traslado, venta) se registran con cabecera y detalle, de modo que el historial logístico queda completo y auditable.

Los diagramas y el diseño técnico están en [`Documentacion/`](Documentacion/).

---

## Estructura del repositorio

```
docker-compose.yml  PostgreSQL 16 en contenedor
setup.sh            Levanta el contenedor y ejecuta los scripts en orden
ScriptSQL/          Scripts numerados, se ejecutan en orden
Datos/              Generadores en Python y script de carga masiva (los CSVs se generan, no se versionan)
Pruebas/            Benchmark, verificaciones de CI, casos de prueba y evidencias de rendimiento
Documentacion/      Modelo conceptual, diagrama relacional, diseño técnico
.github/workflows/  CI en GitHub Actions
```

### Scripts SQL

| Archivo | Contenido |
|---|---|
| `01_Creacion_Estructura.sql` | Creación de las doce tablas |
| `02_Restricciones.sql` | Claves foráneas, dominios, integridad referencial |
| `03_Carga_Datos.sql` | Carga inicial de catálogos y datos de prueba |
| `04_Consultas_Reportes.sql` | Consultas de negocio y reportes |
| `05_Indices.sql` | Índices de optimización |
| `06_Seguridad_Roles.sql` | Roles, permisos y vistas |
| `07_Funciones_Procedimientos.sql` | Funciones, procedimientos y triggers en PL/pgSQL |
| `08_Concurrencia.sql` | Manejo de transacciones y concurrencia |

---

## Cómo ejecutarlo

### Con Docker (recomendado)

**Requisitos:** Docker con el plugin Compose. No hace falta tener PostgreSQL instalado.

```bash
./setup.sh
```

`docker-compose.yml` levanta un contenedor `postgres:16` con la base `proyecto_bd` (usuario y contraseña `postgres`, puerto `5432`) y monta `ScriptSQL/` y `Datos/` en `/proyecto` dentro del contenedor. `setup.sh` espera a que la base esté sana y ejecuta con el `psql` del contenedor, en orden, la creación de estructura, las restricciones, la carga de datos, los índices, los roles y las funciones. Cada script corre con `ON_ERROR_STOP` y el proceso aborta ante el primer error, indicando qué script falló.

Correrlo dos veces seguidas funciona siempre: si detecta restos de una corrida anterior —tablas en el esquema `public`, o los roles de `06_Seguridad_Roles.sql`, que se crean en el cluster y sobreviven a borrar la base— recrea `proyecto_bd` desde cero antes de empezar. `./setup.sh --reset` fuerza esa recreación aunque no haya restos.

Por defecto carga los datos de prueba de `03_Carga_Datos.sql`. Para usar el dataset masivo, primero hay que generarlo (ver [Generación de datos masivos](#generación-de-datos-masivos)) y después:

```bash
CARGA=masiva ./setup.sh
```

Los dos scripts de datos son alternativos, no complementarios: ambos cargan las mismas tablas con ids explícitos desde 1, así que se ejecuta uno u otro. Los dos dejan el inventario cargado. Si faltan los CSVs generados, `setup.sh` lo avisa antes de levantar el contenedor.

Comandos útiles:

```bash
docker compose exec db psql -U postgres -d proyecto_bd   # abrir una consola psql
./setup.sh --reset                                      # recrear la base desde cero
docker compose down -v && ./setup.sh                    # además, borrar el volumen
DB_PORT=5433 ./setup.sh                                 # si el 5432 está ocupado
```

### Sin Docker

**Requisitos:** PostgreSQL 14 o superior. Para el dataset masivo, Python 3 con `pandas` y `numpy`.

```bash
createdb proyecto_bd

psql -d proyecto_bd -f ScriptSQL/01_Creacion_Estructura.sql
psql -d proyecto_bd -f ScriptSQL/02_Restricciones.sql
psql -d proyecto_bd -f ScriptSQL/03_Carga_Datos.sql      # o el dataset masivo, ver abajo
psql -d proyecto_bd -f ScriptSQL/05_Indices.sql
psql -d proyecto_bd -f ScriptSQL/06_Seguridad_Roles.sql
psql -d proyecto_bd -f ScriptSQL/07_Funciones_Procedimientos.sql
```

El orden importa: las restricciones dependen de las tablas, la carga de datos de los catálogos, y los índices conviene crearlos después de cargar los datos.

Para el dataset masivo, en lugar de `03` se ejecuta `cd Datos && psql -d proyecto_bd -f Carga_Masiva.sql`: los `\copy` usan rutas relativas a `Datos/`.

Una vez cargado, `04_Consultas_Reportes.sql` y `08_Concurrencia.sql` contienen consultas y escenarios para ejecutar de forma interactiva. `08_Concurrencia.sql` asume las cantidades de `03_Carga_Datos.sql`: contra el dataset masivo, el trigger de validación rechaza la segunda venta por falta de stock.

---

## Generación de datos masivos

Evaluar el rendimiento con veinte filas no dice nada, así que los datos de prueba se generan por programa en lugar de escribirse a mano.

**`Datos/generar_masivos.py`** produce un catálogo de 1.000 productos y lo escribe en `Datos/generado/productos_masivos.csv`. La categoría se deriva de la prenda, para que el nombre y la clasificación no se contradigan, y el precio se sortea dentro de un rango por categoría en pesos argentinos: de 5.000 a 15.000 las medias, de 15.000 a 40.000 las remeras, de 80.000 a 250.000 las zapatillas, y así para las nueve categorías.

**`Datos/generador_datos.py`** lee ese catálogo y arma el resto del universo de datos con pandas y numpy, respetando las dependencias entre tablas: 8 sucursales, 40 empleados, 18.632 variantes (cada producto cruzado con los talles de su categoría y cuatro colores), 500.000 movimientos entre enero de 2025 y el 14 de septiembre de 2026, y 1.649.014 renglones de detalle. Tres cuartos de los movimientos son ventas. La popularidad de los productos sigue una distribución Zipf-Mandelbrot en lugar de ser uniforme: los cien productos más vendidos suman el 45 % de las unidades y queda una cola larga que casi no se vende, como en un retail real. Los parámetros de escala, precios y distribución están como constantes al principio de cada script.

Los movimientos se sortean sin la noción de que no se puede vender lo que no entró, así que el generador agrega una apertura de inventario: una Entrada por sucursal, fechada el 31 de diciembre de 2024, con la cantidad justa para cubrir el peor bajón de stock de cada variante más un colchón chico. Así `Inventario` es el neto exacto de todos los movimientos, sin pasar nunca por saldo negativo, y el CI verifica que coincida celda por celda con el neto recalculado en SQL.

La salida es un CSV por tabla en `Datos/generado/`, unos 78 MB, que no se versiona. Los dos scripts tienen semilla y fechas fijas, así que dos corridas producen archivos idénticos byte a byte (el CI también lo comprueba) y el generador es la fuente de verdad. `Datos/Carga_Masiva.sql` es un script chico que carga esos CSVs con `\copy`.

El punto de hacerlo así es que las claves foráneas cierren: cada movimiento apunta a un empleado y una sucursal que existen, cada detalle a una variante real. Generar los datos a mano con ese nivel de consistencia es inviable.

```bash
cd Datos
python generar_masivos.py
python generador_datos.py
```

---

## Rendimiento

Evaluar con veinte filas no dice nada, así que las consultas de `04_Consultas_Reportes.sql` se midieron sobre el dataset masivo (500.008 movimientos, 1.649.014 detalles, 18.632 variantes, 374.589 salidas, 149.056 filas de inventario) en dos escenarios: la base recién cargada sin `05_Indices.sql`, y la misma base con los once índices aplicados. Se hizo `ANALYZE` antes de cada escenario.

La medición está automatizada en [`Pruebas/benchmark.sh`](Pruebas/benchmark.sh): levanta la base desde cero, extrae las consultas de `04` y los `CREATE INDEX` de `05` de los propios scripts, mide cada una con `EXPLAIN (ANALYZE, BUFFERS)` y deja los planes completos en `Pruebas/Evidencias_Rendimiento/`. Se tomó el mejor tiempo de quince corridas por consulta. Las quince repeticiones vienen del dataset chico original, donde todo terminaba en menos de un milisegundo y con tres el ruido de medición era del mismo orden que la diferencia a medir; a esta escala las consultas tardan entre 96 y 333 ms y el ruido pesa mucho menos. Dos corridas seguidas de quince repeticiones dieron los mismos tiempos dentro del 2,2 %.

Entorno: PostgreSQL 16.15 en Docker con la configuración por defecto de la imagen (`shared_buffers` de 128 MB, `work_mem` de 4 MB, hasta dos workers paralelos por consulta), en un AMD Ryzen 7 8845HS con 14 GB de RAM. Medido el 14 de septiembre de 2026 con `REPETICIONES=15 Pruebas/benchmark.sh`; la corrida completa, carga incluida, tardó 74 segundos.

Los números corresponden a esa fecha de medición. Las consultas 1 y 2 usan una ventana temporal relativa a `CURRENT_DATE` (el último trimestre y el año en curso) y el historial generado termina en una fecha fija, así que dan filas y tiempos distintos según cuándo se ejecuten.

| # | Consulta | Filas | Sin índices (ms) | Con índices (ms) | Mejora | Índice nuevo que usó el planificador |
|---|---|---|---|---|---|---|
| 1 | Recaudación por marca, salidas del último trimestre | 4 | 114.543 | 96.601 | +16 % | `idx_movimientos_tipo_fecha` |
| 2 | Variantes sin salidas en el año | 450 | 138.624 | 109.316 | +21 % | `idx_detalle_movimientos_id_mov` |
| 3 | Tickets y recaudación por empleado en Sucursal NOA | 5 | 146.876 | 100.259 | +32 % | `idx_detalle_movimientos_id_mov`, `idx_movimientos_id_sucursal_origen` |
| 4 | Variantes con stock bajo | 147323 | 160.935 | 159.166 | +1 % | ninguno, sigue con Seq Scan |
| 5 | Ventas por marca y sucursal | 32 | 328.838 | 332.494 | -1 % | ninguno, sigue con Seq Scan |

El cambio de escala cambia lo que se puede concluir. Con el dataset anterior, de 1.002 movimientos, `Inventario` tenía 96 filas en una sola página de disco y `Detalle_Movimientos` 3.101 filas: leer cualquier tabla entera costaba menos que pasar por un índice, y el benchmark documentaba casi puros resultados nulos. Ahora `Inventario` ocupa 806 páginas y `Detalle_Movimientos` tiene 1,65 millones de filas, y eso es lo que les da sentido a los índices: recién a este tamaño recorrer una tabla completa deja de ser gratis y el planificador tiene algo que ganar entrando por un índice. Donde todavía no lo usa, el motivo es la selectividad del filtro, no el tamaño de la tabla.

La que más gana es la 3, un 32 %, y es la única que usa dos índices. Sin ellos recorre `Movimientos` y `Detalle_Movimientos` enteras en paralelo y las cruza con un hash join. Con ellos, `idx_movimientos_id_sucursal_origen` acota `Movimientos` a los 62.427 con origen en la Sucursal NOA, un octavo de la tabla, y por cada una de las 27.418 ventas de 2025 que quedan entra a `Detalle_Movimientos` por `idx_detalle_movimientos_id_mov`. El plan nuevo ni siquiera usa workers paralelos, y aun así es más rápido.

La 2 gana un 21 % con el mismo índice y el mismo mecanismo: la subconsulta deja de cruzar `Detalle_Movimientos` completa con un hash join y hace 154.840 búsquedas por `idx_detalle_movimientos_id_mov`, una por cada venta del año. Además ahora devuelve 450 filas, variantes que no registraron ninguna venta en lo que va de 2026. Con el dataset anterior daba cero, porque 48 variantes con 1.113 renglones de venta se vendían todas.

La 2 y la 3 comparten un problema que conviene dejar dicho: el planificador estima mal cuántos movimientos pasan el filtro. Las dos filtran el año con `EXTRACT(YEAR FROM fecha_hora)`, una expresión sobre la que PostgreSQL no tiene estadísticas, y en el plan sin índices estima 777 filas por worker donde en realidad hay 51.613 en la 2 y 73.250 en la 3, entre 66 y 94 veces más. Con esa estimación elige búsquedas por índice creyendo que van a ser pocas. Esta vez sale bien, porque cada búsqueda es barata y encuentra unos dos renglones, pero es una decisión tomada con información equivocada. Por esa misma expresión, la parte de fecha de `idx_movimientos_tipo_fecha` no les sirve: un índice sobre `fecha_hora` no puede resolver una condición sobre `EXTRACT(YEAR FROM fecha_hora)`.

La 1 mejora un 16 %, por el mismo motivo que con el dataset chico, solo que ahora se nota: `idx_movimientos_tipo_fecha` reemplaza el recorrido de `Movimientos` por un Bitmap Index Scan que va directo a las 55.216 ventas del último trimestre, y ese paso baja de 16 a 2,4 ms por worker. Lo que no cambia es el resto: `Detalle_Movimientos` se sigue recorriendo entera, las 1,65 millones de filas, porque para cruzarla con 55.216 movimientos el planificador prefiere un hash join a buscar uno por uno, y ese recorrido con su join es lo que domina el tiempo.

La 4 no cambia, pero por una razón distinta a la de antes. `Inventario` ya no cabe en una página, y con un filtro selectivo el planificador sí usa `idx_inventario_cantidad_disponible`: se comprobó con `EXPLAIN` sobre `Inventario` con `cantidad_disponible < 5`, que deja 20.839 filas y se resuelve con un Bitmap Index Scan. El problema es el filtro de la consulta. Su comentario en `04_Consultas_Reportes.sql` dice que busca variantes con menos de 5 unidades, pero el código filtra `< 35`, y con el stock del dataset (mediana de 9 unidades por variante y sucursal) eso abarca 147.323 de las 149.056 filas, el 98,8 %. Para devolver casi toda la tabla, recorrerla es lo correcto. La consulta no se corrigió a propósito: es código de otro integrante y cambiarla rompería la comparabilidad con las mediciones de la Etapa III. El tiempo, además, casi no está en `Inventario`: el recorrido tarda 10 ms y el resto se va en los joins y en ordenar 147.323 filas, que no entran en `work_mem` y se ordenan en disco (8,6 MB).

En la 5 tampoco hay índice que ayude. Suma todas las ventas sin acotar fecha: 374.589 de los 500.008 movimientos, tres cuartos de la tabla, con 748.622 renglones de detalle. Con esa selectividad recorrer es más barato que ir al índice, y el plan es el mismo en los dos escenarios. Es la consulta más cara del benchmark, unos 330 ms.

La popularidad de los productos merece un párrafo aparte. El generador usa una distribución Zipf-Mandelbrot y no una uniforme porque así se venden los productos en un retail real, y un benchmark sobre datos uniformes mediría un escenario que no ocurre. Para ver cuánto pesa eso en estas cinco consultas, se repitió el benchmark completo con popularidad uniforme (`EXPONENTE_POPULARIDAD = 0` y el mismo peso para todos los talles y colores). La consulta 2 pasó de 450 filas a cero: es la diferencia entre un reporte que dice algo y uno vacío. Los planes, en cambio, no cambiaron: los diez tuvieron la misma forma y usaron los mismos índices en los dos datasets, con tiempos que difirieron menos de un 4 %. Ninguna de las cinco consultas filtra por producto o variante, sino por tipo de movimiento, fecha y sucursal, que se reparten igual en los dos casos. Y aun filtrando por variante, el sesgo de este dataset no alcanza para cambiar un plan: la variante más vendida aparece en 6.742 renglones, el 0,4 % de `Detalle_Movimientos`, y se sigue buscando por índice igual que la menos vendida. En este benchmark, el sesgo cambia los resultados, no las decisiones del planificador.

Con el dataset chico, los índices se justificaban por la forma de los planes más que por los milisegundos. A esta escala se justifican también por los milisegundos en las tres consultas que los usan, y las dos que no los usan quedan afuera por la selectividad de sus filtros, no por falta de datos. Los planes completos de las diez mediciones están en [`Pruebas/Evidencias_Rendimiento/`](Pruebas/Evidencias_Rendimiento/), y el informe original de la Etapa III en [`Etapa_III/`](Pruebas/Evidencias_Rendimiento/Etapa_III/).

---

## Seguridad

Tres roles bajo el principio de mínimo privilegio:

| Rol | Permisos |
|---|---|
| `rol_administrador` | Acceso completo a estructura y datos |
| `rol_operativo` | Operaciones del día a día: altas de movimientos, consultas de stock |
| `rol_consulta` | Solo lectura, a través de vistas |

Dos vistas complementan el esquema: `vista_stock_simplificado`, que expone el inventario sin datos sensibles, y `vista_auditoria_movimientos`, para seguimiento del historial.

---

## Lógica de negocio

La lógica crítica vive en la base de datos, no en la aplicación, para que se cumpla sin importar quién escriba.

**Procedimientos:**

- `sp_registrar_entrada_mercaderia` — ingreso desde proveedor
- `sp_registrar_traslado_sucursales` — movimiento entre sucursales
- `sp_registrar_venta_caja` — venta al público
- `sp_actualizar_precios_por_marca` — actualización masiva de precios

**Funciones y triggers:**

- `fn_actualizar_inventario_por_movimiento` / `trg_actualizar_stock_automatico` — el stock se ajusta solo al registrar un movimiento
- `fn_validar_stock_disponible` / `trg_validar_stock_antes_insertar` — impide vender o trasladar más de lo que hay
- `fn_autocompletar_precio_unitario` / `trg_autocompletar_precio_detalle` — toma el precio vigente del producto al armar el detalle

---

## Concurrencia

`08_Concurrencia.sql` y `Pruebas/Casos_Prueba/Prueba_Transacciones.sql` plantean escenarios con sesiones simultáneas operando sobre el mismo inventario, con `COMMIT` y `ROLLBACK` explícitos, para verificar que dos ventas concurrentes de la última unidad no dejen el stock en negativo.

---

## Mi rol en el proyecto

Trabajo grupal de seis integrantes. Lo que sigue es lo que escribí yo, verificable con `git log` y `git blame`.

**Diseño del esquema.** El modelo de datos completo: `01_Creacion_Estructura.sql` y `02_Restricciones.sql` — las doce tablas, la separación producto/variante, las claves primarias y foráneas con sus políticas `ON DELETE`/`ON UPDATE`, y las restricciones `UNIQUE` y `CHECK`. También el modelo conceptual y el diagrama relacional de `Documentacion/`.

**Roles y permisos.** `06_Seguridad_Roles.sql`: los tres roles bajo mínimo privilegio y las dos vistas.

**Generación de datos masivos.** `Datos/generar_masivos.py` y `Datos/generador_datos.py`, los dos scripts en Python que producen el dataset que carga `Carga_Masiva.sql`, respetando las dependencias entre tablas.

**Reproducibilidad.** `docker-compose.yml` y `setup.sh`, para que el proyecto se levante con un comando en lugar de seis `psql` manuales.

**Documentación.** El README en su forma actual, incluida la medición comparativa de consultas con y sin índices sobre el dataset masivo.

Del resto del equipo: la carga de datos de prueba (`03_Carga_Datos.sql`) y la concurrencia (`08_Concurrencia.sql`), de Quintero; las consultas y reportes (`04_Consultas_Reportes.sql`), las funciones y triggers en PL/pgSQL (`07_Funciones_Procedimientos.sql`) y las pruebas de transacciones, de Escalante; los índices (`05_Indices.sql`) y las mediciones de la Etapa III, de Yapura.





---

Parte del trabajo posterior a la entrega (CI, automatización del benchmark,
escalado del dataset masivo, documentación) se hizo con asistencia de
Claude Code, bajo revisión y decisiones de diseño propias.
