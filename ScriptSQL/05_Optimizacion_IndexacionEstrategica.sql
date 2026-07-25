-- ==============================================================================
-- OBJETIVOS: 
--          ● Análisis mediante el planificador de PostgreSQL. 
--          ● Uso de herramientas como EXPLAIN y EXPLAIN ANALYZE.  
--          ● Comparación del rendimiento antes y después de aplicar mejoras. 
--          ● Campos utilizados frecuentemente en búsquedas.  
--          ● Claves utilizadas en relaciones.  
--          ● Consultas críticas del sistema. 
-- ==============================================================================

-- Prueba de rendimiento de la tabla "Detalle_Movimientos"
EXPLAIN ANALYZE
SELECT 
    mrc.nombre AS marca_deportiva,
    SUM(dm.cantidad) AS total_prendas_vendidas,
    SUM(dm.cantidad * dm.precio_unitario) AS recaudacion_total
FROM Movimientos mov
INNER JOIN Detalle_Movimientos dm ON mov.id_movimiento = dm.id_movimiento
INNER JOIN Producto_Variante pv ON dm.id_variante = pv.id_variante
INNER JOIN Productos prod ON pv.id_producto = prod.id_producto
INNER JOIN Marcas mrc ON prod.id_marca = mrc.id_marca
WHERE mov.tipo_movimiento = 'Salida' 
  AND mov.fecha_hora >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY mrc.id_marca, mrc.nombre
ORDER BY recaudacion_total DESC;

-- Creacion de indices para optimizar el rendimiento de las consultas
-- Índice para acelerar los JOINs con la tabla Movimientos (Query 1, 3 y 5)
CREATE INDEX idx_detalle_movimientos_id_mov 
ON public.Detalle_Movimientos(id_movimiento);

-- Índice para acelerar los JOINs con las variantes de producto (Query 2)
CREATE INDEX idx_detalle_movimientos_id_var 
ON public.Detalle_Movimientos(id_variante);

------------------------------------------------------------------------------

-- Prueba de rendimiento de la tabla "Movimientos"
EXPLAIN ANALYZE
SELECT 
    emp.nombre,
    emp.apellido,
    suc.nombre AS sucursal,
    COUNT(DISTINCT mov.id_movimiento) AS cantidad_tickets_emitidos,
    SUM(dm.cantidad * dm.precio_unitario) AS total_plata_ingresada
FROM Movimientos mov
INNER JOIN Empleados emp ON mov.id_empleado = emp.id_empleado
INNER JOIN Sucursales suc ON mov.id_sucursal_origen = suc.id_sucursal
INNER JOIN Detalle_Movimientos dm ON mov.id_movimiento = dm.id_movimiento
WHERE mov.tipo_movimiento = 'Salida'
  AND suc.nombre = 'Sucursal NOA'
  AND EXTRACT(YEAR FROM mov.fecha_hora) = 2025
GROUP BY 
    emp.id_empleado, 
    emp.nombre, 
    emp.apellido, 
    suc.nombre
ORDER BY 
    cantidad_tickets_emitidos DESC, 
    total_plata_ingresada DESC;

-- Creacion de indices para optimizar el rendimiento de las consultas
-- 1. Índice estratégico para acelerar la vinculación con la tabla de Empleados
CREATE INDEX idx_movimientos_id_empleado 
ON public.Movimientos(id_empleado);

-- 2. Índice estratégico para acelerar el filtrado y JOIN con la tabla de Sucursales
CREATE INDEX idx_movimientos_id_sucursal_origen 
ON public.Movimientos(id_sucursal_origen);

------------------------------------------------------------------------------

-- Prueba de rendimiento de la tabla "Inventario"
EXPLAIN ANALYZE
SELECT 
    suc.nombre AS sucursal,
    prod.nombre AS producto,
    tal.nomenclatura AS talle,
    col.nombre_color AS color,
    inv.cantidad_disponible AS stock_actual
FROM Inventario inv
INNER JOIN Sucursales suc ON inv.id_sucursal = suc.id_sucursal
INNER JOIN Producto_Variante pv ON inv.id_variante = pv.id_variante
INNER JOIN Productos prod ON pv.id_producto = prod.id_producto
INNER JOIN Talles tal ON pv.id_talle = tal.id_talle
INNER JOIN Colores col ON pv.id_color = col.id_color
WHERE inv.cantidad_disponible < 35
ORDER BY 
    suc.nombre ASC, 
    inv.cantidad_disponible ASC;

-- Creacion de indices para optimizar el rendimiento de las consultas
CREATE INDEX idx_inventario_cantidad_disponible 
ON public.Inventario(cantidad_disponible);

------------------------------------------------------------------------------

-- Prueba de rendimiento de la tabla "Producto_Variante"

EXPLAIN ANALYZE
SELECT 
    mrc.nombre AS marca,
    prod.nombre AS producto,
    tal.nomenclatura AS talle,
    col.nombre_color AS color
FROM Producto_Variante pv
INNER JOIN Productos prod ON pv.id_producto = prod.id_producto
INNER JOIN Marcas mrc ON prod.id_marca = mrc.id_marca
INNER JOIN Talles tal ON pv.id_talle = tal.id_talle
INNER JOIN Colores col ON pv.id_color = col.id_color
WHERE pv.id_variante NOT IN (
    SELECT dm.id_variante 
    FROM Detalle_Movimientos dm
    INNER JOIN Movimientos mov ON dm.id_movimiento = mov.id_movimiento
    WHERE mov.tipo_movimiento = 'Salida'
      AND EXTRACT(YEAR FROM mov.fecha_hora) = EXTRACT(YEAR FROM CURRENT_DATE)
)
ORDER BY mrc.nombre, prod.nombre;

-- Creacion de indices para optimizar el rendimiento de las consultas
-- 1. Índice para acelerar el JOIN con la tabla de Productos
CREATE INDEX idx_producto_variante_id_producto 
ON public.Producto_Variante(id_producto);

-- 2. Índice para acelerar el JOIN con la tabla de Talles
CREATE INDEX idx_producto_variante_id_talle 
ON public.Producto_Variante(id_talle);

-- 3. Índice para acelerar el JOIN con la tabla de Colores
CREATE INDEX idx_producto_variante_id_color 
ON public.Public.Producto_Variante(id_color);

------------------------------------------------------------------------------

-- Prueba de rendimiento de la tabla "Productos"
EXPLAIN ANALYZE
SELECT 
    suc.nombre AS sucursal,
    mrc.nombre AS marca,
    SUM(dm.cantidad) AS total_unidades_vendidas,
    SUM(dm.cantidad * dm.precio_unitario) AS recaudacion_por_marca
FROM Movimientos mov
INNER JOIN Sucursales suc ON mov.id_sucursal_origen = suc.id_sucursal
INNER JOIN Detalle_Movimientos dm ON mov.id_movimiento = dm.id_movimiento
INNER JOIN Producto_Variante pv ON dm.id_variante = pv.id_variante
INNER JOIN Productos prod ON pv.id_producto = prod.id_producto
INNER JOIN Marcas mrc ON prod.id_marca = mrc.id_marca
WHERE mov.tipo_movimiento = 'Salida'
GROUP BY 
    suc.nombre, 
    mrc.nombre
ORDER BY 
    suc.nombre ASC, 
    recaudacion_por_marca DESC;

-- Creacion de indices para optimizar el rendimiento de las consultas
-- 1. Índice para acelerar el JOIN entre Productos y Marcas (Query 1, 2 y 5)
CREATE INDEX idx_productos_id_marca 
ON public.Productos(id_marca);

-- 2. Índice estratégico para optimizar búsquedas y filtrados por Categoría
CREATE INDEX idx_productos_id_categoria 
ON public.Productos(id_categoria);


------------------------------------------------------------------------------


--Índice Compuesto Avanzado en "Movimientos"
EXPLAIN ANALYZE
SELECT 
    mrc.nombre AS marca_deportiva,
    SUM(dm.cantidad) AS total_prendas_vendidas,
    SUM(dm.cantidad * dm.precio_unitario) AS recaudacion_total
FROM Movimientos mov
INNER JOIN Detalle_Movimientos dm ON mov.id_movimiento = dm.id_movimiento
INNER JOIN Producto_Variante pv ON dm.id_variante = pv.id_variante
INNER JOIN Productos prod ON pv.id_producto = prod.id_producto
INNER JOIN Marcas mrc ON prod.id_marca = mrc.id_marca
WHERE mov.tipo_movimiento = 'Salida' 
  AND mov.fecha_hora >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY mrc.id_marca, mrc.nombre
ORDER BY recaudacion_total DESC;


-- Creacion de indices para optimizar el rendimiento de las consultas
CREATE INDEX idx_movimientos_tipo_fecha 
ON public.Movimientos(tipo_movimiento, fecha_hora);