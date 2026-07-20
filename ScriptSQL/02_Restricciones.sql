-- ==========================================
-- SCRIPT 02: RESTRICCIONES E INTEGRIDAD
-- ==========================================

-- RESTRICCIONES UNIQUE (Evitar duplicados)
ALTER TABLE Categorias ADD CONSTRAINT uq_categoria_nombre UNIQUE (nombre);
ALTER TABLE Marcas ADD CONSTRAINT uq_marca_nombre UNIQUE (nombre);
ALTER TABLE Proveedores ADD CONSTRAINT uq_proveedor_cuit UNIQUE (cuit);
ALTER TABLE Empleados ADD CONSTRAINT uq_empleado_documento UNIQUE (documento);
ALTER TABLE Talles ADD CONSTRAINT uq_talle_nomenclatura UNIQUE (nomenclatura);
ALTER TABLE Colores ADD CONSTRAINT uq_color_nombre UNIQUE (nombre_color);
ALTER TABLE Producto_Variante ADD CONSTRAINT uq_variante_codigo UNIQUE (codigo_barras);

-- RESTRICCIONES CHECK (Reglas de dominio)
ALTER TABLE Empleados ADD CONSTRAINT chk_perfil_acceso 
    CHECK (perfil_acceso IN ('Administrador', 'Operativo', 'Consulta'));

ALTER TABLE Productos ADD CONSTRAINT chk_precio_positivo 
    CHECK (precio_venta_actual > 0);

ALTER TABLE Inventario ADD CONSTRAINT chk_stock_positivo 
    CHECK (cantidad_disponible >= 0);

ALTER TABLE Movimientos ADD CONSTRAINT chk_tipo_movimiento 
    CHECK (tipo_movimiento IN ('Entrada', 'Salida', 'Traslado'));

ALTER TABLE Detalle_Movimientos ADD CONSTRAINT chk_cantidad_movimiento 
    CHECK (cantidad > 0);
ALTER TABLE Detalle_Movimientos ADD CONSTRAINT chk_precio_movimiento 
    CHECK (precio_unitario >= 0);

-- CLAVES FORÁNEAS (Integridad Referencial con ON DELETE/ON UPDATE)

-- Relaciones de Productos
ALTER TABLE Productos 
    ADD CONSTRAINT fk_producto_marca FOREIGN KEY (id_marca) REFERENCES Marcas(id_marca) ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES Categorias(id_categoria) ON DELETE RESTRICT ON UPDATE CASCADE;

-- Relaciones de Producto_Variante
ALTER TABLE Producto_Variante 
    ADD CONSTRAINT fk_variante_producto FOREIGN KEY (id_producto) REFERENCES Productos(id_producto) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT fk_variante_talle FOREIGN KEY (id_talle) REFERENCES Talles(id_talle) ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_variante_color FOREIGN KEY (id_color) REFERENCES Colores(id_color) ON DELETE RESTRICT ON UPDATE CASCADE;

-- Relaciones de Inventario
ALTER TABLE Inventario 
    ADD CONSTRAINT fk_inventario_sucursal FOREIGN KEY (id_sucursal) REFERENCES Sucursales(id_sucursal) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT fk_inventario_variante FOREIGN KEY (id_variante) REFERENCES Producto_Variante(id_variante) ON DELETE CASCADE ON UPDATE CASCADE;

-- Relaciones de Movimientos
ALTER TABLE Movimientos 
    ADD CONSTRAINT fk_movimiento_origen FOREIGN KEY (id_sucursal_origen) REFERENCES Sucursales(id_sucursal) ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_movimiento_destino FOREIGN KEY (id_sucursal_destino) REFERENCES Sucursales(id_sucursal) ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_movimiento_empleado FOREIGN KEY (id_empleado) REFERENCES Empleados(id_empleado) ON DELETE RESTRICT ON UPDATE CASCADE;

-- Relaciones de Detalle de Movimientos
ALTER TABLE Detalle_Movimientos 
    ADD CONSTRAINT fk_detalle_movimiento FOREIGN KEY (id_movimiento) REFERENCES Movimientos(id_movimiento) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT fk_detalle_variante FOREIGN KEY (id_variante) REFERENCES Producto_Variante(id_variante) ON DELETE RESTRICT ON UPDATE CASCADE;