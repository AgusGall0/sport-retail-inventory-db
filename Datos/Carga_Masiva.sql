-- ==============================================================================
-- CARGA MASIVA
-- ==============================================================================
-- Carga con \copy los CSVs que dejan en Datos/generado/ los generadores:
--
--   cd Datos
--   python generar_masivos.py
--   python generador_datos.py
--
-- Los CSVs no se versionan: con semilla fija la salida es siempre la misma.
--
-- Se usa \copy (del lado del cliente) y no COPY (del lado del servidor) para
-- que funcione aunque el servidor no vea el disco de quien ejecuta, como el
-- service de PostgreSQL del CI. Las rutas son relativas al directorio desde el
-- que corre psql, que tiene que ser Datos/:
--
--   cd Datos && psql -d proyecto_bd -f Carga_Masiva.sql
--
-- Va despues de 01 y 02 y antes de 07: sin triggers activos, Inventario se
-- carga tal como lo calculo el generador, que es el neto de todos los
-- movimientos.
-- ==============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Nivel 0: catalogos
\copy Marcas (id_marca, nombre) FROM 'generado/marcas.csv' WITH (FORMAT csv, HEADER true)
\copy Categorias (id_categoria, nombre) FROM 'generado/categorias.csv' WITH (FORMAT csv, HEADER true)
\copy Talles (id_talle, nomenclatura) FROM 'generado/talles.csv' WITH (FORMAT csv, HEADER true)
\copy Colores (id_color, nombre_color) FROM 'generado/colores.csv' WITH (FORMAT csv, HEADER true)

-- Nivel 1: semidependientes
\copy Sucursales (id_sucursal, nombre, direccion, ciudad) FROM 'generado/sucursales.csv' WITH (FORMAT csv, HEADER true)
\copy Proveedores (id_proveedor, razon_social, cuit, telefono, email) FROM 'generado/proveedores.csv' WITH (FORMAT csv, HEADER true)
\copy Empleados (id_empleado, documento, nombre, apellido, perfil_acceso) FROM 'generado/empleados.csv' WITH (FORMAT csv, HEADER true)
\copy Productos (id_producto, nombre, descripcion, precio_venta_actual, id_marca, id_categoria) FROM 'generado/productos.csv' WITH (FORMAT csv, HEADER true)

-- Nivel 2
\copy Producto_Variante (id_variante, id_producto, id_talle, id_color, codigo_barras) FROM 'generado/producto_variante.csv' WITH (FORMAT csv, HEADER true)

-- Nivel 3: la apertura de inventario va primera en los dos archivos
\copy Movimientos (id_movimiento, fecha_hora, tipo_movimiento, observaciones, id_sucursal_origen, id_sucursal_destino, id_empleado, id_proveedor) FROM 'generado/movimientos.csv' WITH (FORMAT csv, HEADER true)
\copy Detalle_Movimientos (id_detalle, cantidad, precio_unitario, id_movimiento, id_variante) FROM 'generado/detalle_movimientos.csv' WITH (FORMAT csv, HEADER true)

-- Nivel 4: el stock resultante de aplicar todos los movimientos
\copy Inventario (id_sucursal, id_variante, cantidad_disponible) FROM 'generado/inventario.csv' WITH (FORMAT csv, HEADER true)

-- Las columnas SERIAL no avanzan su secuencia cuando el id se carga a mano, asi
-- que sin esto la secuencia sigue en 1 y el primer INSERT que delegue el id
-- (por ejemplo sp_registrar_venta_caja) choca con clave duplicada. Con
-- is_called en false el proximo nextval devuelve exactamente MAX(id) + 1.
DO $$
BEGIN
    PERFORM setval(pg_get_serial_sequence(tabla, columna), COALESCE(maximo, 0) + 1, false)
    FROM (VALUES
        ('marcas', 'id_marca', (SELECT MAX(id_marca) FROM Marcas)),
        ('categorias', 'id_categoria', (SELECT MAX(id_categoria) FROM Categorias)),
        ('talles', 'id_talle', (SELECT MAX(id_talle) FROM Talles)),
        ('colores', 'id_color', (SELECT MAX(id_color) FROM Colores)),
        ('sucursales', 'id_sucursal', (SELECT MAX(id_sucursal) FROM Sucursales)),
        ('proveedores', 'id_proveedor', (SELECT MAX(id_proveedor) FROM Proveedores)),
        ('empleados', 'id_empleado', (SELECT MAX(id_empleado) FROM Empleados)),
        ('productos', 'id_producto', (SELECT MAX(id_producto) FROM Productos)),
        ('producto_variante', 'id_variante', (SELECT MAX(id_variante) FROM Producto_Variante)),
        ('movimientos', 'id_movimiento', (SELECT MAX(id_movimiento) FROM Movimientos)),
        ('detalle_movimientos', 'id_detalle', (SELECT MAX(id_detalle) FROM Detalle_Movimientos))
    ) AS secuencias (tabla, columna, maximo);
END $$;

COMMIT;
