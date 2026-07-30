--                      TRIGGER_BAJO NIVEL
-- ==============================================================================
-- ETAPA V: PROGRAMABILIDAD - GESTIÓN AUTÓNOMA DE INVENTARIO
-- ==============================================================================

CREATE OR REPLACE FUNCTION fn_actualizar_inventario_por_movimiento()
RETURNS TRIGGER AS $$
DECLARE
    v_tipo_movimiento VARCHAR(20);
    v_suc_origen INT;
    v_suc_destino INT;
BEGIN
    -- AVISO 1: Saber si el trigger se ejecuta
    RAISE NOTICE 'TRIGGER ACTIVADO: Evaluando Variante % en Movimiento %', NEW.id_variante, NEW.id_movimiento;

    -- Capturamos los metadatos del movimiento padre
    SELECT tipo_movimiento, id_sucursal_origen, id_sucursal_destino
    INTO v_tipo_movimiento, v_suc_origen, v_suc_destino
    FROM Movimientos
    WHERE id_movimiento = NEW.id_movimiento;

    -- AVISO 2: Ver qué datos leyó el motor
    RAISE NOTICE 'DATOS CAPTURADOS: Tipo: %, Suc. Origen: %, Suc. Destino: %', v_tipo_movimiento, v_suc_origen, v_suc_destino;

    -- ==========================================================================
    -- ESCENARIO A: ENTRADA DE MERCADERÍA
    -- ==========================================================================
    IF v_tipo_movimiento = 'Entrada' THEN
        RAISE NOTICE 'Procesando rama de ENTRADA. Sumando % unidades...', NEW.cantidad;
        
        UPDATE Inventario 
        SET cantidad_disponible = cantidad_disponible + NEW.cantidad
        WHERE id_sucursal = v_suc_origen AND id_variante = NEW.id_variante;
        
        IF NOT FOUND THEN
            RAISE NOTICE 'Registro nuevo: Creando celda de stock en Sucursal %', v_suc_origen;
            INSERT INTO Inventario (id_sucursal, id_variante, cantidad_disponible)
            VALUES (v_suc_origen, NEW.id_variante, NEW.cantidad);
        END IF;

    -- ==========================================================================
    -- ESCENARIO B: SALIDA DE MERCADERÍA
    -- ==========================================================================
    ELSIF v_tipo_movimiento = 'Salida' THEN
        RAISE NOTICE 'Procesando rama de SALIDA. Restando % unidades...', NEW.cantidad;
        UPDATE Inventario 
        SET cantidad_disponible = cantidad_disponible - NEW.cantidad
        WHERE id_sucursal = v_suc_origen AND id_variante = NEW.id_variante;

    -- ==========================================================================
    -- ESCENARIO C: TRASLADO ENTRE SUCURSALES
    -- ==========================================================================
    ELSIF v_tipo_movimiento = 'Traslado' THEN
        RAISE NOTICE 'Procesando rama de TRASLADO. Moviendo % unidades de % a %', NEW.cantidad, v_suc_origen, v_suc_destino;
        
        UPDATE Inventario 
        SET cantidad_disponible = cantidad_disponible - NEW.cantidad
        WHERE id_sucursal = v_suc_origen AND id_variante = NEW.id_variante;
        
        UPDATE Inventario 
        SET cantidad_disponible = cantidad_disponible + NEW.cantidad
        WHERE id_sucursal = v_suc_destino AND id_variante = NEW.id_variante;
        
        IF NOT FOUND THEN
            INSERT INTO Inventario (id_sucursal, id_variante, cantidad_disponible)
            VALUES (v_suc_destino, NEW.id_variante, NEW.cantidad);
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aseguramos que el disparador esté bien enlazado
CREATE OR REPLACE TRIGGER trg_actualizar_stock_automatico
AFTER INSERT ON Detalle_Movimientos
FOR EACH ROW
EXECUTE FUNCTION fn_actualizar_inventario_por_movimiento();




-- ==============================================================================
-- PROGRAMABILIDAD - CONTROL DE CONSISTENCIA (SHIELD TRIGGER)
-- ==============================================================================

-- 1. Creación de la Función de Validación
CREATE OR REPLACE FUNCTION fn_validar_stock_disponible()
RETURNS TRIGGER AS $$
DECLARE
    v_tipo_movimiento VARCHAR(20);
    v_suc_origen INT;
    v_stock_actual INT;
BEGIN
    -- Obtenemos el tipo de movimiento y la sucursal de origen
    SELECT tipo_movimiento, id_sucursal_origen
    INTO v_tipo_movimiento, v_suc_origen
    FROM Movimientos
    WHERE id_movimiento = NEW.id_movimiento;

    -- La validación se aplica solamente a operaciones que restan stock
    IF v_tipo_movimiento IN ('Salida', 'Traslado') THEN

        -- Se consulta y bloquea la fila correspondiente del inventario
        SELECT cantidad_disponible
        INTO v_stock_actual
        FROM Inventario
        WHERE id_sucursal = v_suc_origen
        AND id_variante = NEW.id_variante
        FOR UPDATE;

        -- Si la variante no existe en el inventario, se considera stock cero
        IF NOT FOUND THEN
            v_stock_actual := 0;
        END IF;

        RAISE NOTICE
        'CONTROL DE CONCURRENCIA: Variante %, Sucursal %, Stock %, Solicitado %',
        NEW.id_variante,
        v_suc_origen,
        v_stock_actual,
        NEW.cantidad;

        -- Validación del stock disponible
        IF v_stock_actual < NEW.cantidad THEN
            RAISE EXCEPTION
            'STOCK INSUFICIENTE. Variante: %, Sucursal: %, Disponible: %, Solicitado: %',
            NEW.id_variante,
            v_suc_origen,
            v_stock_actual,
            NEW.cantidad;
        END IF;

        RAISE NOTICE
        'STOCK BLOQUEADO Y VALIDADO CORRECTAMENTE PARA LA TRANSACCIÓN.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 2. Vinculación del Trigger ANTES de que impacte el Detalle
CREATE OR REPLACE TRIGGER trg_validar_stock_antes_insertar
BEFORE INSERT ON Detalle_Movimientos
FOR EACH ROW
EXECUTE FUNCTION fn_validar_stock_disponible();





-- ==============================================================================
-- PROGRAMABILIDAD - GESTIÓN AUTOMATIZADA DE PRECIOS (PRICE TRIGGER)
-- ==============================================================================

-- 1. Creación de la Función de Inyección de Precios
CREATE OR REPLACE FUNCTION fn_autocompletar_precio_unitario()
RETURNS TRIGGER AS $$
DECLARE
    v_tipo_movimiento VARCHAR(20);
    v_precio_oficial DECIMAL(12,2);
    v_nombre_producto VARCHAR(150);
BEGIN
    -- Capturamos el tipo de movimiento padre
    SELECT tipo_movimiento INTO v_tipo_movimiento
    FROM Movimientos
    WHERE id_movimiento = NEW.id_movimiento;

    -- Solo automatizamos el precio si es una venta ('Salida') y el precio viene en 0
    IF v_tipo_movimiento = 'Salida' AND NEW.precio_unitario = 0 THEN
        
        -- Buscamos el precio oficial del catálogo cruzando la variante con el producto general
        SELECT p.nombre, p.precio_venta_actual 
        INTO v_nombre_producto, v_precio_oficial
        FROM Productos p
        JOIN Producto_Variante pv ON p.id_producto = pv.id_producto
        WHERE pv.id_variante = NEW.id_variante;

        -- TELEMETRÍA DE DEPURACIÓN (Ver comportamiento tras bambalinas)
        RAISE NOTICE 'AUTOMATIZACIÓN DE PRECIOS: Se detectó precio 0.00 en Venta para la Variante %', NEW.id_variante;
        RAISE NOTICE 'BÚSQUEDA EN CATÁLOGO: Producto: "%" | Precio Oficial Encontrado: %', v_nombre_producto, v_precio_oficial;

        -- Si encontramos el producto, sobreescribimos el 0 por el precio real del catálogo
        IF v_precio_oficial IS NOT NULL THEN
            NEW.precio_unitario := v_precio_oficial;
            RAISE NOTICE 'INYECCIÓN EXITOSA: Sobreescribiendo precio_unitario con % antes de guardar en disco.', NEW.precio_unitario;
        ELSE
            RAISE NOTICE 'ADVERTENCIA: No se encontró un precio oficial para la variante %. Se guardará en 0.', NEW.id_variante;
        END IF;
    END IF;

    -- Continúa el flujo de inserción con el precio corregido
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 2. Vinculación del Trigger ANTES de la inserción física
CREATE OR REPLACE TRIGGER trg_autocompletar_precio_detalle
BEFORE INSERT ON Detalle_Movimientos
FOR EACH ROW
EXECUTE FUNCTION fn_autocompletar_precio_unitario();







--          PROCEDIMIENTOS ALMACENADOS_ALTO NVEL
-- ==============================================================================
-- PROGRAMABILIDAD - PROCEDIMIENTO ALMACENADO DE ENTRADA
-- ==============================================================================
CREATE OR REPLACE PROCEDURE sp_registrar_entrada_mercaderia(
    p_id_sucursal INT,
    p_id_empleado INT,
    p_id_proveedor INT,
    p_observaciones TEXT,
    p_id_variante INT,
    p_cantidad INT,
    p_precio_unitario DECIMAL(12,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_movimiento INT;
BEGIN
    -- 1. Intentamos insertar la cabecera del movimiento
    INSERT INTO Movimientos (tipo_movimiento, observaciones, id_sucursal_origen, id_sucursal_destino, id_empleado, id_proveedor)
    VALUES ('Entrada', p_observaciones, p_id_sucursal, NULL, p_id_empleado, p_id_proveedor)
    RETURNING id_movimiento INTO v_id_movimiento;

    -- 2. Intentamos insertar el detalle (Aquí saltarán los triggers de stock si hubiera reglas)
    INSERT INTO Detalle_Movimientos (id_movimiento, id_variante, cantidad, precio_unitario)
    VALUES (v_id_movimiento, p_id_variante, p_cantidad, p_precio_unitario);

    RAISE NOTICE '✅ PROCEDIMIENTO EXITOSO: Entrada registrada bajo el Movimiento N° %', v_id_movimiento;

-- BLOQUE DE CONTROL DE EXCEPCIONES SEGURO (Sin conflictos de COMMIT interno)
EXCEPTION WHEN OTHERS THEN
    -- El motor intercepta el fallo, avisa en consola y relanza la excepción 
    -- para que el bloque externo (BEGIN...COMMIT) ejecute el ROLLBACK automáticamente.
    RAISE EXCEPTION '❌ ERROR OPERATIVO EN ENTRADA DE MERCADERÍA: %', SQLERRM;
END;
$$;



-- ==============================================================================
-- PROGRAMABILIDAD - PROCEDIMIENTO ALMACENADO DE TRASLADO LOGÍSTICO
-- ==============================================================================

CREATE OR REPLACE PROCEDURE sp_registrar_traslado_sucursales(
    p_id_sucursal_origen INT,
    p_id_sucursal_destino INT,
    p_id_empleado INT,
    p_observaciones TEXT,
    p_id_variante INT,
    p_cantidad INT,
    p_precio_unitario DECIMAL(12,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_movimiento INT;
BEGIN
    -- 1. Validación de Negocio: El origen y el destino no pueden ser la misma sucursal
    IF p_id_sucursal_origen = p_id_sucursal_destino THEN
        RAISE EXCEPTION '🚨 ERROR LOGÍSTICO (UNCA): La sucursal de origen y la de destino no pueden ser idénticas (ID: %)', p_id_sucursal_origen;
    END IF;

    -- 2. Validación: Asegurar que se indique un destino válido
    IF p_id_sucursal_destino IS NULL THEN
        RAISE EXCEPTION '🚨 ERROR LOGÍSTICO (UNCA): Todo traslado requiere obligatoriamente una sucursal de destino.';
    END IF;

    -- 3. Insertamos la cabecera del movimiento especificando origen y destino
    INSERT INTO Movimientos (tipo_movimiento, observaciones, id_sucursal_origen, id_sucursal_destino, id_empleado, id_proveedor)
    VALUES ('Traslado', p_observaciones, p_id_sucursal_origen, p_id_sucursal_destino, p_id_empleado, NULL)
    RETURNING id_movimiento INTO v_id_movimiento;

    -- 4. Insertamos el renglón en el detalle 
    -- Al hacer esto, el motor activará en cadena:
    --   a) El escudo de stock (verificando que el origen tenga suficientes unidades)
    --   b) El trigger de actualización de inventario (restando en origen y sumando en destino)
    INSERT INTO Detalle_Movimientos (id_movimiento, id_variante, cantidad, precio_unitario)
    VALUES (v_id_movimiento, p_id_variante, p_cantidad, p_precio_unitario);

    RAISE NOTICE '✅ TRASLADO EXITOSO: Movimiento N° % registrado. Movilizando % unidades de Sucursal % a Sucursal %', 
                 v_id_movimiento, p_cantidad, p_id_sucursal_origen, p_id_sucursal_destino;

-- Bloque de control de excepciones seguro
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION '❌ ERROR OPERATIVO EN TRASLADO LOGÍSTICO: %', SQLERRM;
END;
$$;





-- ==============================================================================
-- PROGRAMABILIDAD - PROCEDIMIENTO DE ACTUALIZACIÓN MASIVA DE PRECIOS
-- ==============================================================================

CREATE OR REPLACE PROCEDURE sp_actualizar_precios_por_marca(
    p_id_marca INT,
    p_porcentaje_ajuste DECIMAL(5,2) -- Ejemplo: 10.00 para aumentar un 10%, -5.00 para reducir un 5%
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nombre_marca VARCHAR(100);
    v_filas_afectadas INT;
BEGIN
    -- 1. Validación de Negocio: Verificar que la marca exista en el catálogo
    SELECT nombre INTO v_nombre_marca
    FROM Marcas
    WHERE id_marca = p_id_marca;

    IF v_nombre_marca IS NULL THEN
        RAISE EXCEPTION '🚨 ERROR DE GESTIÓN (UNCA): La marca con ID % no se encuentra registrada en el sistema.', p_id_marca;
    END IF;

    -- 2. Actualización Masiva: Aplicar el porcentaje de ajuste sobre el precio actual de los productos de la marca
    UPDATE Productos
    SET precio_venta_actual = precio_venta_actual * (1.0 + (p_porcentaje_ajuste / 100.0))
    WHERE id_marca = p_id_marca;

    -- 3. Obtenemos cuántos productos fueron modificados gracias al diagnóstico del motor
    GET DIAGNOSTICS v_filas_afectadas = ROW_COUNT;

    -- 4. Telemetría de éxito
    RAISE NOTICE '✅ ACTUALIZACIÓN MASIVA EXITOSA: Se ajustaron los precios de la marca "%" (ID: %) en un %% %. Total de productos actualizados: %', 
                 v_nombre_marca, p_id_marca, p_porcentaje_ajuste, v_filas_afectadas;

-- Manejo de excepciones seguro
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION '❌ ERROR OPERATIVO EN ACTUALIZACIÓN MASIVA DE PRECIOS: %', SQLERRM;
END;
$$;





-- ==============================================================================
-- PROGRAMABILIDAD - PROCEDIMIENTO ALMACENADO DE VENTA EN CAJA (SALIDA)
-- ==============================================================================

CREATE OR REPLACE PROCEDURE sp_registrar_venta_caja(
    p_id_sucursal INT,
    p_id_empleado INT,
    p_observaciones TEXT,
    p_id_variante INT,
    p_cantidad INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_movimiento INT;
BEGIN
    -- 1. Insertamos la cabecera del movimiento de tipo 'Salida' (Venta)
    INSERT INTO Movimientos (tipo_movimiento, observaciones, id_sucursal_origen, id_sucursal_destino, id_empleado, id_proveedor)
    VALUES ('Salida', p_observaciones, p_id_sucursal, NULL, p_id_empleado, NULL)
    RETURNING id_movimiento INTO v_id_movimiento;

    -- 2. Insertamos el renglón en el detalle enviando precio en 0.00 
    -- (Esto activará automáticamente el Trigger de Precios para buscar el catálogo y el Escudo de Stock)
    INSERT INTO Detalle_Movimientos (id_movimiento, id_variante, cantidad, precio_unitario)
    VALUES (v_id_movimiento, p_id_variante, p_cantidad, 0.00);

    RAISE NOTICE '✅ VENTA REGISTRADA EXITOSAMENTE: Movimiento N° % en Sucursal %', v_id_movimiento, p_id_sucursal;

-- Bloque de control de excepciones seguro
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION '❌ ERROR OPERATIVO EN VENTA DE CAJA: %', SQLERRM;
END;
$$;