-- PRUEBA DE CONCURRENCIA

-- Se utilizan dos sesiones distintas de pgAdmin, donde ambas intentan registrar una venta sobre la misma sucursal y la misma variante de producto.

-- SESIÓN 1 - Usuario administrador Usuario: usr_admin Contraseña: AdminCata
BEGIN;

CALL sp_registrar_venta_caja(
    1,                                      -- Sucursal
    1,                                      -- Empleado
    'Prueba de concurrencia Administrador', -- Observaciones
    1,                                      -- Variante
    7                                       -- Cantidad
);

-- No ejecutar todavía el COMMIT.
-- La transacción permanece abierta y mantiene bloqueada
-- la fila correspondiente del inventario.

-- Ejecutar este COMMIT recién después de iniciar
-- la operación en la Sesión 2.

COMMIT;


-- En otra Query --
-- SESIÓN 2 - Usuario de caja Usuario: usr_caja Contraseña: OperativoStock 

BEGIN;

CALL sp_registrar_venta_caja(
    1,                              -- Sucursal
    2,                              -- Empleado
    'Prueba de concurrencia U2',    -- Observaciones
    1,                              -- Variante
    7                               -- Cantidad
);

-- Esta operación queda en espera mientras la Sesión 1
-- mantiene bloqueada la fila del inventario.

-- Si existe stock suficiente:
COMMIT;

-- Si el trigger genera una excepción por stock insuficiente,
-- ejecutar en lugar del COMMIT:
ROLLBACK;