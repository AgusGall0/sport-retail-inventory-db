-- 1==============================================================================
-- Objetivo: Mostrar las marcas que generaron mas ingresos economicos 
--           filtrando unicamente las 'Salidas' de los últimos 3 meses.
-- Elementos: Multiples JOINs, Agrupamiento (GROUP BY), Funciones (SUM).
-- ==============================================================================
SELECT 
    mrc.nombre AS marca_deportiva,
    SUM(dm.cantidad) AS total_prendas_vendidas,
    SUM(dm.cantidad * dm.precio_unitario) AS recaudacion_total
FROM Movimientos mov

-- Unimos el movimiento con su detalle (relacion contiene)
INNER JOIN Detalle_Movimientos dm ON mov.id_movimiento = dm.id_movimiento

-- Unimos el detalle con la variante exacta que se vendio
INNER JOIN Producto_Variante pv ON dm.id_variante = pv.id_variante

-- Unimos la variante con el producto general (relacion "Posee")
INNER JOIN Productos prod ON pv.id_producto = prod.id_producto

-- 4. Unimos el producto con su marca (La relación "Pertenece")
INNER JOIN Marcas mrc ON prod.id_marca = mrc.id_marca

-- Solo ventas y del último trimestre
WHERE mov.tipo_movimiento = 'Salida' 
  AND mov.fecha_hora >= CURRENT_DATE - INTERVAL '3 months'

-- Agrupamiento por marca
GROUP BY mrc.id_marca, mrc.nombre

-- Ordenamos para generar el "Top"
ORDER BY recaudacion_total DESC;

--2
-- Objetivo: Identificar que variantes especificas (talle/color) de los productos 
-- no registraron movimientos de 'Salida' durante el año actual.
-- Elementos: Subconsulta (NOT IN), Multiples JOINs.
-- ==============================================================================
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

-- subconsulta. Buscamos lo que "NO ESTÁ" en la lista de ventas.
WHERE pv.id_variante NOT IN (
    
-- Subconsulta: Esta es la lista de todas las variantes que SÍ se vendieron este año
SELECT dm.id_variante 
FROM Detalle_Movimientos dm
INNER JOIN Movimientos mov ON dm.id_movimiento = mov.id_movimiento
WHERE mov.tipo_movimiento = 'Salida'
AND EXTRACT(YEAR FROM mov.fecha_hora) = EXTRACT(YEAR FROM CURRENT_DATE)
      
)
ORDER BY mrc.nombre, prod.nombre;



-- ==============================================================================
-- 3 Objetivo: Determinar que empleado genero la mayor cantidad de tickets de 
--           venta y recaudacion en la Sucursal NOA durante el año 2025.
-- Elementos: Filtros complejos (AND, EXTRACT), COUNT DISTINCT, SUM, GROUP BY.
-- ==============================================================================
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

-- Filtramos Salidas, en Sucursal NOA, solo para el año 2025
WHERE mov.tipo_movimiento = 'Salida'
  AND suc.nombre = 'Sucursal NOA'
  AND EXTRACT(YEAR FROM mov.fecha_hora) = 2025

-- Agrupamos por los datos del empleado y sucursal
GROUP BY 
    emp.id_empleado, 
    emp.nombre, 
    emp.apellido, 
    suc.nombre

-- Ordenamos por cantidad de tickets (y si empatan, desempatan por plata)
ORDER BY 
    cantidad_tickets_emitidos DESC, 
    total_plata_ingresada DESC;


-- ==============================================================================
-- 4 Objetivo: Identificar las variantes exactas de productos (talle y color) 
-- que están en nivel de urgencia de stock (menos de 5 unidades disponibles).
-- Elementos: Multiples JOINs (6 tablas), Filtros complejos numéricos.
-- ==============================================================================
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

-- Filtramos solo lo que esta en bajo stock (menos de 35 unidades)
WHERE inv.cantidad_disponible < 35

-- Ordenamos por sucursal y luego priorizamos los numeros mas bajos de stock
ORDER BY 
    suc.nombre ASC, 
    inv.cantidad_disponible ASC;




-- ==============================================================================
-- 5 Objetivo: Comparar el volumen de ventas y recaudacion por Marca en cada 
--           Sucursal para analizar el comportamiento  de los clientes.
-- Elementos: Múltiples JOINs, Funciones Agregadas (SUM), Agrupamiento por dos campos.
-- ==============================================================================
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

-- Solo evaluamos las ventas (Salidas)
WHERE mov.tipo_movimiento = 'Salida'

-- Agrupamos por sucursal y por marca para hacer la comparativa 
GROUP BY 
    suc.nombre, 
    mrc.nombre

-- Ordenamos por sucursal y por la marca que mas recaudo en cada una
ORDER BY 
    suc.nombre ASC, 
    recaudacion_por_marca DESC;


