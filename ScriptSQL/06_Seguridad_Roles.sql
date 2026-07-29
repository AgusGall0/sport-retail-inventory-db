-- ==============================================================================
-- OBJETIVOS: 
--          ● Implementación de seguridad y control de acceso mediante roles (RBAC).
--          ● Definición de perfiles de acceso: Administrador, Operativo y Consulta.
--          ● Aplicación del principio de mínimo privilegio.
--          ● Creación de vistas orientadas a ocultar información sensible.
--          ● Simplificación del acceso a datos para usuarios de reportes.
-- ==============================================================================


-- 1. CREACIÓN DE VISTAS DE SEGURIDAD Y SIMPLIFICACIÓN

-- Vista 1: Catálogo y Stock Simplificado
-- Simplifica los JOINs para reportes y oculta los IDs internos físicos.
CREATE VIEW vista_stock_simplificado AS
SELECT 
    s.nombre AS sucursal,
    p.nombre AS producto,
    m.nombre AS marca,
    t.nomenclatura AS talle,
    c.nombre_color AS color,
    pv.codigo_barras,
    i.cantidad_disponible
FROM Inventario i
JOIN Sucursales s ON i.id_sucursal = s.id_sucursal
JOIN Producto_Variante pv ON i.id_variante = pv.id_variante
JOIN Productos p ON pv.id_producto = p.id_producto
JOIN Marcas m ON p.id_marca = m.id_marca
JOIN Talles t ON pv.id_talle = t.id_talle
JOIN Colores c ON pv.id_color = c.id_color;

-- Vista 2: Auditoría de Movimientos con Enmascaramiento
-- Oculta información sensible, como el DNI del empleado y el CUIT del proveedor.
CREATE VIEW vista_auditoria_movimientos AS
SELECT 
    mov.fecha_hora,
    mov.tipo_movimiento,
    suc_o.nombre AS sucursal_origen,
    suc_d.nombre AS sucursal_destino,
    CONCAT(LEFT(emp.documento, 2), '******') AS documento_empleado_enmascarado,
    CONCAT(emp.nombre, ' ', emp.apellido) AS empleado_responsable,
    CONCAT(LEFT(prov.cuit, 2), '-', SUBSTRING(prov.cuit FROM 4 FOR 4), '****-*') AS cuit_proveedor_enmascarado,
    prov.razon_social AS proveedor
FROM Movimientos mov
LEFT JOIN Empleados emp ON mov.id_empleado = emp.id_empleado
LEFT JOIN Sucursales suc_o ON mov.id_sucursal_origen = suc_o.id_sucursal
LEFT JOIN Sucursales suc_d ON mov.id_sucursal_destino = suc_d.id_sucursal
LEFT JOIN Proveedores prov ON mov.id_proveedor = prov.id_proveedor;


-- 2. CREACIÓN DE ROLES BASE (RBAC)
CREATE ROLE rol_administrador;
CREATE ROLE rol_operativo;
CREATE ROLE rol_consulta;

-- 3. APLICACIÓN DEL PRINCIPIO DE MÍNIMO PRIVILEGIO

-- Permisos Rol: Administrador (Acceso total al esquema)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rol_administrador;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_administrador;

-- Permisos Rol: Operativo (Puede cargar movimientos y ver stock, pero no alterar configuración ni empleados)
GRANT SELECT ON Categorias, Marcas, Proveedores, Sucursales, Productos, Talles, Colores, Producto_Variante, Empleados TO rol_operativo;
GRANT SELECT, INSERT, UPDATE ON Inventario, Movimientos, Detalle_Movimientos TO rol_operativo;

-- Permiso para que el operativo pueda usar los autoincrementales al insertar
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_operativo;

-- Permisos Rol: Consulta (Acceso estrictamente limitado a las vistas seguras)
GRANT SELECT ON vista_stock_simplificado, vista_auditoria_movimientos TO rol_consulta;


-- 4. CREACIÓN DE USUARIOS DEL SISTEMA Y ASIGNACIÓN A ROLES
CREATE USER usr_admin WITH PASSWORD 'AdminCata';
GRANT rol_administrador TO usr_admin;

CREATE USER usr_caja_noa WITH PASSWORD 'OperativoStock';
GRANT rol_operativo TO usr_caja_noa;

CREATE USER usr_auditor WITH PASSWORD 'AuditoriaSoloLectura';
GRANT rol_consulta TO usr_auditor;