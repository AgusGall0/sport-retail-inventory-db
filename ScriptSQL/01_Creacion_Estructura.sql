-- ==========================================
-- SCRIPT 01: CREACIÓN DE ESTRUCTURA BASE
-- ==========================================

-- 1. ENTIDADES MAESTRAS (CATÁLOGOS)
CREATE TABLE Categorias (
    id_categoria SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT
);

CREATE TABLE Marcas (
    id_marca SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE Proveedores (
    id_proveedor SERIAL PRIMARY KEY,
    razon_social VARCHAR(150) NOT NULL,
    cuit VARCHAR(20) NOT NULL,
    telefono VARCHAR(50),
    email VARCHAR(100)
);

CREATE TABLE Sucursales (
    id_sucursal SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    direccion VARCHAR(200),
    ciudad VARCHAR(100)
);

CREATE TABLE Empleados (
    id_empleado SERIAL PRIMARY KEY,
    documento VARCHAR(20) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    perfil_acceso VARCHAR(50) NOT NULL
);

-- 2. PRODUCTOS Y VARIANTES (3FN)
CREATE TABLE Productos (
    id_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    precio_venta_actual DECIMAL(12,2) NOT NULL,
    id_marca INT NOT NULL,
    id_categoria INT NOT NULL
);

CREATE TABLE Talles (
    id_talle SERIAL PRIMARY KEY,
    nomenclatura VARCHAR(20) NOT NULL
);

CREATE TABLE Colores (
    id_color SERIAL PRIMARY KEY,
    nombre_color VARCHAR(50) NOT NULL
);

CREATE TABLE Producto_Variante (
    id_variante SERIAL PRIMARY KEY,
    codigo_barras VARCHAR(50) NOT NULL,
    id_producto INT NOT NULL,
    id_talle INT NOT NULL,
    id_color INT NOT NULL
);

-- 3. TRANSACCIONAL (STOCK Y MOVIMIENTOS)
CREATE TABLE Inventario (
    id_sucursal INT NOT NULL,
    id_variante INT NOT NULL,
    cantidad_disponible INT NOT NULL,
    PRIMARY KEY (id_sucursal, id_variante)
);

CREATE TABLE Movimientos (
    id_movimiento SERIAL PRIMARY KEY,
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    tipo_movimiento VARCHAR(20) NOT NULL,
    observaciones TEXT,
    id_sucursal_origen INT,
    id_sucursal_destino INT,
    id_empleado INT NOT NULL,
	id_proveedor INT
);

CREATE TABLE Detalle_Movimientos (
    id_detalle SERIAL PRIMARY KEY,
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(12,2) NOT NULL,
    id_movimiento INT NOT NULL,
    id_variante INT NOT NULL
);