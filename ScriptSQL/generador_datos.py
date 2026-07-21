import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random

# ==========================================
# 1. GENERACIÓN DE DATAFRAMES (NIVEL 0 Y 1)
# ==========================================

# Nivel 0: Catálogos
df_marcas = pd.DataFrame({
    'id_marca': [1, 2, 3, 4], 
    'nombre': ['Nike', 'Adidas', 'Puma', 'Under Armour']
})

df_categorias = pd.DataFrame({
    'id_categoria': [1, 2, 3], 
    'nombre': ['Calzado Running', 'Remeras Técnicas', 'Pantalones']
})

df_talles = pd.DataFrame({
    'id_talle': [1, 2, 3, 4, 5, 6], 
    'nomenclatura': ['S', 'M', 'L', '40', '41', '42']
})

df_colores = pd.DataFrame({
    'id_color': [1, 2, 3, 4], 
    'nombre_color': ['Negro', 'Blanco', 'Gris', 'Azul']
})

# Nivel 1: Semidependientes
df_sucursales = pd.DataFrame({
    'id_sucursal': [1, 2], 
    'nombre': ['Central CABA', 'Sucursal NOA'],
    'direccion': ['Av. Corrientes 3200', 'Rivadavia 550'],
    'ciudad': ['Buenos Aires', 'Catamarca']
})

df_proveedores = pd.DataFrame({
    'id_proveedor': [1, 2],
    'razon_social': ['Nike Argentina', 'Adidas Latam'],
    'cuit': ['30-12345678-9', '30-98765432-1'],
    'telefono': ['11-1234-5678', '11-8765-4321'],
    'email': ['ventas@nike.com', 'ventas@adidas.com']
})

df_empleados = pd.DataFrame({
    'id_empleado': [1, 2],
    'documento': ['35111222', '38444555'],
    'nombre': ['Carlos', 'Laura'],
    'apellido': ['Gómez', 'Díaz'],
    'perfil_acceso': ['Administrador', 'Operativo']
})

# Productos Base (Cabecera)
df_productos = pd.DataFrame({
    'id_producto': [1, 2],
    'nombre': ['Pegasus 40', 'Ultraboost'],
    'descripcion': ['Running neutra', 'Running retorno energia'],
    'precio_venta_actual': [150000.0, 175000.0],
    'id_marca': [1, 2],
    'id_categoria': [1, 1]
})


# ==========================================
# 2. GENERACIÓN DE VARIANTES (NIVEL 2)
# ==========================================
print("Generando Producto_Variante (Cross Join)...")

# Realizamos un producto cartesiano (Cross Join) nativo de Pandas 
# cruzando productos, talles y colores.
df_temp1 = df_productos[['id_producto']].merge(df_talles[['id_talle']], how='cross')
df_variantes = df_temp1.merge(df_colores[['id_color']], how='cross')

# Agregamos IDs autoincrementales y generamos un código de barras (EAN simulado)
df_variantes['id_variante'] = range(1, len(df_variantes) + 1)
df_variantes['codigo_barras'] = df_variantes['id_variante'].apply(lambda x: f"779{x:09d}")

# Reordenamos las columnas
df_variantes = df_variantes[['id_variante', 'id_producto', 'id_talle', 'id_color', 'codigo_barras']]


# ==========================================
# 3. GENERACIÓN DE MOVIMIENTOS (NIVEL 3)
# ==========================================
print("Generando Movimientos transaccionales...")
CANTIDAD_MOVIMIENTOS = 1000

movimientos_list = []
detalle_list = []
id_detalle = 1

# Generador de fechas aleatorias
def random_date(start_date, end_date):
    delta = end_date - start_date
    random_seconds = random.randrange(int(delta.total_seconds()))
    return start_date + timedelta(seconds=random_seconds)

inicio = datetime(2025, 1, 1)
fin = datetime.now()

for i in range(1, CANTIDAD_MOVIMIENTOS + 1):
    fecha = random_date(inicio, fin).strftime('%Y-%m-%d %H:%M:%S')
    tipo = random.choice(['Entrada', 'Salida', 'Traslado'])
    id_sucursal_origen = random.choice(df_sucursales['id_sucursal'].tolist())
    
    # Manejo básico de destino según el tipo de movimiento
    id_sucursal_destino = 'NULL'
    if tipo == 'Traslado':
        destinos_posibles = df_sucursales[df_sucursales['id_sucursal'] != id_sucursal_origen]['id_sucursal'].tolist()
        id_sucursal_destino = random.choice(destinos_posibles) if destinos_posibles else 'NULL'

    id_empleado = random.choice(df_empleados['id_empleado'].tolist())
    
    movimientos_list.append([i, fecha, tipo, 'Generado por script Pandas', id_empleado, id_sucursal_origen, id_sucursal_destino])
    
    # Crear entre 1 y 5 detalles para cada movimiento
    cant_detalles = random.randint(1, 5)
    for _ in range(cant_detalles):
        variante = random.choice(df_variantes['id_variante'].tolist())
        cantidad = random.randint(1, 20)
        precio = random.choice(df_productos['precio_venta_actual'].tolist()) * random.uniform(0.7, 1.0) # Precio con posible descuento
        detalle_list.append([i, variante, cantidad, round(precio, 2)])
        id_detalle += 1

df_movimientos = pd.DataFrame(movimientos_list, columns=['id_movimiento', 'fecha_hora', 'tipo_movimiento', 'observaciones', 'id_empleado', 'id_sucursal_origen', 'id_sucursal_destino'])
df_detalle = pd.DataFrame(detalle_list, columns=['id_movimiento', 'id_variante', 'cantidad', 'precio_unitario'])

# --- AGREGA ESTAS TRES LÍNEAS ACÁ ---
df_detalle['id_movimiento'] = df_detalle['id_movimiento'].astype(int)
df_detalle['id_variante'] = df_detalle['id_variante'].astype(int)
df_detalle['cantidad'] = df_detalle['cantidad'].astype(int)
# ------------------------------------


# ==========================================
# 4. EXPORTACIÓN A ARCHIVO SQL
# ==========================================
print("Exportando a Carga_Masiva.sql...")

def df_to_sql_insert(df, table_name):
    """Convierte un DataFrame de Pandas en sentencias INSERT de SQL"""
    sql_statements = f"\n-- Inserciones para {table_name}\n"
    for index, row in df.iterrows():
        values = []
        for val in row.values:
            if pd.isna(val) or val == 'NULL':
                values.append("NULL")
            elif isinstance(val, (int, np.integer, float, np.floating)):
                values.append(str(val))
            else:
                # Escapar comillas simples para SQL
                escaped_val = str(val).replace("'", "''")
                values.append(f"'{escaped_val}'")
        
        sql_statements += f"INSERT INTO {table_name} ({', '.join(df.columns)}) VALUES ({', '.join(values)});\n"
    return sql_statements

# Escribimos el archivo en el orden jerárquico correcto
with open("Carga_Masiva.sql", "w", encoding="utf-8") as file:
    file.write("-- SCRIPT GENERADO AUTOMÁTICAMENTE\n")
    
    # Nivel 0
    file.write(df_to_sql_insert(df_marcas, 'Marcas'))
    file.write(df_to_sql_insert(df_categorias, 'Categorias'))
    file.write(df_to_sql_insert(df_talles, 'Talles'))
    file.write(df_to_sql_insert(df_colores, 'Colores'))
    
    # Nivel 1
    file.write(df_to_sql_insert(df_sucursales, 'Sucursales'))
    file.write(df_to_sql_insert(df_proveedores, 'Proveedores'))
    file.write(df_to_sql_insert(df_empleados, 'Empleados'))
    file.write(df_to_sql_insert(df_productos, 'Productos'))
    
    # Nivel 2
    file.write(df_to_sql_insert(df_variantes, 'Producto_Variante'))
    
    # Nivel 3
    file.write(df_to_sql_insert(df_movimientos, 'Movimientos'))
    # Suponiendo que el rombo [Contiene] se transformó en la tabla Detalle_Movimientos
    file.write(df_to_sql_insert(df_detalle, 'Detalle_Movimientos')) 

print("¡Archivo Carga_Masiva.sql generado con éxito!")