-- ==============================================================================
-- VERIFICACIONES DE INTEGRIDAD
-- ==============================================================================
-- Se corren despues de ejecutar los ocho scripts de ScriptSQL/. Cada bloque
-- lanza una excepcion si algo no esta como corresponde; ejecutado con
-- ON_ERROR_STOP=1 eso alcanza para que falle el build de CI.
--
-- Tambien se puede correr a mano contra una base ya cargada:
--   docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d proyecto_bd \
--     -f /proyecto/Pruebas/verificaciones_ci.sql
-- ==============================================================================

\set ON_ERROR_STOP on

-- 1. Las doce tablas del modelo tienen que existir --------------------------
DO $$
DECLARE
    esperadas TEXT[] := ARRAY[
        'categorias', 'marcas', 'talles', 'colores',
        'proveedores', 'sucursales', 'empleados',
        'productos', 'producto_variante',
        'inventario', 'movimientos', 'detalle_movimientos'];
    faltantes TEXT[];
BEGIN
    SELECT array_agg(t ORDER BY t) INTO faltantes
    FROM unnest(esperadas) AS t
    WHERE to_regclass('public.' || t) IS NULL;

    IF faltantes IS NOT NULL THEN
        RAISE EXCEPTION 'Faltan % de las 12 tablas del modelo: %',
            array_length(faltantes, 1), array_to_string(faltantes, ', ');
    END IF;
    RAISE NOTICE 'OK  Las 12 tablas del modelo existen';
END $$;

-- 2. Ninguna tabla puede quedar vacia despues de la carga -------------------
DO $$
DECLARE
    tabla TEXT;
    filas BIGINT;
    vacias TEXT[] := '{}';
BEGIN
    FOREACH tabla IN ARRAY ARRAY[
        'categorias', 'marcas', 'talles', 'colores',
        'proveedores', 'sucursales', 'empleados',
        'productos', 'producto_variante',
        'inventario', 'movimientos', 'detalle_movimientos']
    LOOP
        EXECUTE format('SELECT count(*) FROM %I', tabla) INTO filas;
        -- RAISE no entiende los anchos tipo printf, de ahi el rpad
        RAISE NOTICE '    % %', rpad(tabla, 22), filas;
        IF filas = 0 THEN
            vacias := vacias || tabla;
        END IF;
    END LOOP;

    IF array_length(vacias, 1) > 0 THEN
        RAISE EXCEPTION 'Tablas sin datos despues de la carga: %',
            array_to_string(vacias, ', ');
    END IF;
    RAISE NOTICE 'OK  Las 12 tablas tienen datos';
END $$;

-- 3. El stock no puede ser negativo -----------------------------------------
-- Lo garantiza chk_stock_positivo, pero se verifica igual: si alguna vez se
-- afloja la restriccion o se carga el inventario por otra via, esto lo detecta.
DO $$
DECLARE
    negativas INT;
    detalle TEXT;
BEGIN
    SELECT count(*) INTO negativas FROM Inventario WHERE cantidad_disponible < 0;
    IF negativas > 0 THEN
        SELECT string_agg(format('(sucursal %s, variante %s) = %s',
                                 id_sucursal, id_variante, cantidad_disponible), '; ')
        INTO detalle
        FROM (SELECT * FROM Inventario WHERE cantidad_disponible < 0 LIMIT 5) AS m;
        RAISE EXCEPTION 'Hay % filas de Inventario con stock negativo. Primeras: %',
            negativas, detalle;
    END IF;
    RAISE NOTICE 'OK  No hay stock negativo en Inventario';
END $$;

-- 4. Inventario tiene que ser el neto de todos los movimientos --------------
-- Se recalcula el stock desde el historial con la misma semantica que
-- fn_actualizar_inventario_por_movimiento (Entrada suma en origen, Salida resta
-- en origen, Traslado resta en origen y suma en destino) y se compara celda por
-- celda. El FULL OUTER JOIN detecta tambien celdas que estan de un lado solo.
DO $$
DECLARE
    discrepancias INT;
    detalle TEXT;
BEGIN
    CREATE TEMP TABLE neto_recalculado ON COMMIT DROP AS
    WITH deltas AS (
        SELECT m.id_sucursal_origen AS id_sucursal, d.id_variante,
               CASE WHEN m.tipo_movimiento = 'Entrada' THEN d.cantidad ELSE -d.cantidad END AS delta
        FROM Detalle_Movimientos d
        JOIN Movimientos m ON m.id_movimiento = d.id_movimiento
        UNION ALL
        SELECT m.id_sucursal_destino, d.id_variante, d.cantidad
        FROM Detalle_Movimientos d
        JOIN Movimientos m ON m.id_movimiento = d.id_movimiento
        WHERE m.tipo_movimiento = 'Traslado'
    )
    SELECT COALESCE(i.id_sucursal, n.id_sucursal) AS id_sucursal,
           COALESCE(i.id_variante, n.id_variante) AS id_variante,
           i.cantidad_disponible AS en_inventario,
           n.cantidad AS recalculado
    FROM Inventario i
    FULL OUTER JOIN (SELECT id_sucursal, id_variante, SUM(delta) AS cantidad
                     FROM deltas GROUP BY id_sucursal, id_variante) n
      ON n.id_sucursal = i.id_sucursal AND n.id_variante = i.id_variante
    WHERE COALESCE(i.cantidad_disponible, 0) <> COALESCE(n.cantidad, 0);

    SELECT count(*) INTO discrepancias FROM neto_recalculado;
    IF discrepancias > 0 THEN
        SELECT string_agg(format('(sucursal %s, variante %s) inventario %s, recalculado %s',
                                 id_sucursal, id_variante, en_inventario, recalculado), '; ')
        INTO detalle
        FROM (SELECT * FROM neto_recalculado LIMIT 5) AS m;
        RAISE EXCEPTION 'Hay % celdas donde Inventario no coincide con el neto de movimientos. Primeras: %',
            discrepancias, detalle;
    END IF;
    DROP TABLE neto_recalculado;
    RAISE NOTICE 'OK  Inventario coincide con el neto de los movimientos';
END $$;

-- 5. Los indices de 05_Indices.sql tienen que estar creados -----------------
DO $$
DECLARE
    creados INT;
BEGIN
    SELECT count(*) INTO creados
    FROM pg_indexes
    WHERE schemaname = 'public' AND indexname LIKE 'idx\_%';

    IF creados < 11 THEN
        RAISE EXCEPTION 'Se esperaban 11 indices idx_* de 05_Indices.sql y hay %', creados;
    END IF;
    RAISE NOTICE 'OK  Los % indices de 05_Indices.sql estan creados', creados;
END $$;

-- 6. Roles y vistas de 06_Seguridad_Roles.sql -------------------------------
DO $$
DECLARE
    faltantes TEXT[];
BEGIN
    SELECT array_agg(r ORDER BY r) INTO faltantes
    FROM unnest(ARRAY['rol_administrador', 'rol_operativo', 'rol_consulta']) AS r
    WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r);
    IF faltantes IS NOT NULL THEN
        RAISE EXCEPTION 'Faltan roles: %', array_to_string(faltantes, ', ');
    END IF;

    SELECT array_agg(v ORDER BY v) INTO faltantes
    FROM unnest(ARRAY['vista_stock_simplificado', 'vista_auditoria_movimientos']) AS v
    WHERE to_regclass('public.' || v) IS NULL;
    IF faltantes IS NOT NULL THEN
        RAISE EXCEPTION 'Faltan vistas: %', array_to_string(faltantes, ', ');
    END IF;
    RAISE NOTICE 'OK  Roles y vistas de 06_Seguridad_Roles.sql presentes';
END $$;

-- 7. Funciones, procedimientos y triggers de 07 -----------------------------
DO $$
DECLARE
    faltantes TEXT[];
BEGIN
    SELECT array_agg(r ORDER BY r) INTO faltantes
    FROM unnest(ARRAY[
        'fn_actualizar_inventario_por_movimiento',
        'fn_validar_stock_disponible',
        'fn_autocompletar_precio_unitario',
        'sp_registrar_entrada_mercaderia',
        'sp_registrar_traslado_sucursales',
        'sp_registrar_venta_caja',
        'sp_actualizar_precios_por_marca']) AS r
    WHERE NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = r);
    IF faltantes IS NOT NULL THEN
        RAISE EXCEPTION 'Faltan rutinas de 07: %', array_to_string(faltantes, ', ');
    END IF;

    SELECT array_agg(t ORDER BY t) INTO faltantes
    FROM unnest(ARRAY[
        'trg_actualizar_stock_automatico',
        'trg_validar_stock_antes_insertar',
        'trg_autocompletar_precio_detalle']) AS t
    WHERE NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = t AND NOT tgisinternal);
    IF faltantes IS NOT NULL THEN
        RAISE EXCEPTION 'Faltan triggers de 07: %', array_to_string(faltantes, ', ');
    END IF;
    RAISE NOTICE 'OK  Rutinas y triggers de 07_Funciones_Procedimientos.sql presentes';
END $$;

\echo 'Todas las verificaciones pasaron.'
