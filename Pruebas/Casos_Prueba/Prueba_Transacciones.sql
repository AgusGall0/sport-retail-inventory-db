-- ==============================================================================
-- GESTION DE TRANSACCIONES 
-- Prueba 1: VENTA EXITOSA (COMMIT)
-- ==============================================================================

-- 1. Inicia la transaccion 
BEGIN;

-- 2. Consultamos el stock inicial de la variante 1 en la Sucursal 2, la del NOA 
SELECT 'ANTES DE LA VENTA' AS estado, id_sucursal, id_variante, cantidad_disponible 
FROM Inventario 
WHERE id_sucursal = 2 AND id_variante = 1;

-- 3. Realizamos una venta en caja de 4 unidades de la variante 1
CALL sp_registrar_venta_caja(
    2,                                   -- Sucursal 2: NOA
    2,                                   -- Empleado 2: (Laura Diaz - CON ROL Operativo)
    'Transaccion Exitosa: Venta al publico en Catamarca',
    1,                                   -- Variante 1 (Pegasus 40)
    4                                    -- Cantidad vendida: 4 unidades
);

-- 4. Verificamos que el stock se haya descontado correctamente dentro de la transaccion
SELECT 'DESPUES DE LA VENTA' AS estado, id_sucursal, id_variante, cantidad_disponible 
FROM Inventario 
WHERE id_sucursal = 2 AND id_variante = 1;

--ROLLBACK;
-- 5. Se guardan los cambios 
COMMIT;

-- 6. Verificacion despues del commit
SELECT 'ESTADO FINAL (CONFIRMADO)' AS estado, id_sucursal, id_variante, cantidad_disponible 
FROM Inventario 
WHERE id_sucursal = 2 AND id_variante = 1;


-- ==============================================================================
-- Prueba 2: VENTA FALLIDA POR QUIEBRE DE STOCK (ROLLBACK)
-- ==============================================================================

-- 1. Inicia la transaccion 
BEGIN;

-- 2. Consultamos el stock actual de la variante 1 en la Sucursal NOA
SELECT 'ESTADO INICIAL' AS estado, id_sucursal, id_variante, cantidad_disponible 
FROM Inventario 
WHERE id_sucursal = 2 AND id_variante = 1;

-- 3. Intentamos realizar una venta masiva (500 unidades)
-- Esto va a fallar a proposito ya que no hay suficiente stock 
CALL sp_registrar_venta_caja(
    2,                                   -- Sucursal 2: NOA
    2,                                   -- Empleado 2: Laura Díaz (Operativo)
    'Intento de venta fraudulenta masiva',
    1,                                   -- Variante 1 (Pegasus 40)
    500                                  -- Cantidad: 500 unidades
);

-- 4. Ejecutamos ROLLBACK para limpiar el error y devolver la BD a su estado sin errores.
ROLLBACK;

-- 5. Verificamos que la base de datos bloque la venta y el stock quedo intacto
SELECT 'ESTADO FINAL evitado por fallo en la transaccion)' AS estado, id_sucursal, id_variante, cantidad_disponible 
FROM Inventario 
WHERE id_sucursal = 2 AND id_variante = 1;


-- ==============================================================================
-- Prueba 3: INGRESO DE PROVEEDOR CON RECUPERACION PARCIAL (SAVEPOINT)
-- ==============================================================================

-- 1. Inicia la transaccion 
BEGIN;

-- 2. Consultamos stock inicial (Ej: Variante 2 en Sucursal 1 - CABA)
SELECT 'ANTES DEL INGRESO' AS estado, id_sucursal, id_variante, cantidad_disponible 
FROM Inventario 
WHERE id_sucursal = 1 AND id_variante = 2;

-- 3. Cargamos el Lote 1 (100 unidades)
CALL sp_registrar_entrada_mercaderia(
    1,                                   -- Sucursal 1: Central CABA
    1,                                   -- Empleado 1: Carlos Gomez (Admin)
    1,                                   -- Proveedor 1: Nike Argentina S.A.
    'Lote 1: Ingreso correcto de zapatillas',
    2,                                   -- Variante 2 (Pegasus 40 talle 40 Blanco)
    100,                                 -- Cantidad: 100 unidades
    90000.00                             -- Precio de costo
);

-- 4. punto de guardado por si algo sale mal durante la transaccion 
SAVEPOINT lote_1;

-- 5. Intentamos cargar el Lote 2, pero el empleado tipea mal la cantidad (-20)
-- Esto lanza un error porque viola la regla CHECK de que la cantidad debe ser mayor a cero (cantidad > 0)
CALL sp_registrar_entrada_mercaderia(
    1, 1, 1, 'Lote 2: Error en la cantidad ', 2, -20, 90000.00
);

-- 6. El Lote 2 falla En lugar de hacer un ROLLBACK total y perder el Lote 1, 
-- volvemos hasta el punto de guardado.
ROLLBACK TO SAVEPOINT lote_1;

-- 7. Confirmamos definitivamente la transaccion en donde se guarda el Lote 1, se descarta el 2
COMMIT;

-- 8. Verificamos que las 100 unidades del Lote 1 si se sumaron al inventario
SELECT 'ESTADO FINAL (LOTE 1 GUARDADO)' AS estado, id_sucursal, id_variante, cantidad_disponible 
FROM Inventario 
WHERE id_sucursal = 1 AND id_variante = 2;


-- ============================================================================== 
-- Prueba 4: TRASLADO INTER-SUCURSALES BLINDADO (ATOMICIDAD COMPLEJA)
-- ==============================================================================

-- 1. Inicia la transaccion
BEGIN;

-- 2. Consultamos el stock en ambas sucursales antes del traslado
-- Usaremos la Variante 3 (Remera Dry-Fit Academy)
SELECT 'ANTES DEL TRASLADO' AS estado, id_sucursal, id_variante, cantidad_disponible 
FROM Inventario 
WHERE id_variante = 3 AND id_sucursal IN (1, 2)
ORDER BY id_sucursal;

-- 3. Ejecutamos el traslado de 10 unidades desde CABA (variante 1) hacia el NOA ( variante 2)
CALL sp_registrar_traslado_sucursales(
    1,                                   -- Sucursal Origen: 1 (Central CABA)
    2,                                   -- Sucursal Destino: 2 (Sucursal NOA)
    1,                                   -- Empleado 1: Carlos Gómez (Admin)
    'Traslado de remeras para cubrir picos de demanda en el NOA',
    3,                                   -- Variante 3 (Remera Dry-Fit)
    10,                                  -- Cantidad: 10 unidades
    52000.00                             -- Precio de costo
);

-- 4. Verificamos como impacto la resta y la suma en ambas sucursales a la vez
SELECT 'DURANTE EL TRASLADO' AS estado, id_sucursal, id_variante, cantidad_disponible 
FROM Inventario 
WHERE id_variante = 3 AND id_sucursal IN (1, 2)
ORDER BY id_sucursal;

-- 5. Sellamos la operacion como un bloque atomico exitoso
COMMIT;

-- 6. Verificamos el estado de la transaccion
SELECT 'ESTADO FINAL (CONFIRMADO)' AS estado, id_sucursal, id_variante, cantidad_disponible 
FROM Inventario 
WHERE id_variante = 3 AND id_sucursal IN (1, 2)
ORDER BY id_sucursal;
