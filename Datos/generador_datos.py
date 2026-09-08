import pandas as pd
import numpy as np
from collections import defaultdict
from datetime import datetime, timedelta
import random

# Semilla fija: sin esto cada corrida generaba un dataset distinto y los tiempos
# publicados en el README dejaban de ser re-derivables. Fija la forma del
# dataset (tipos, sucursales, variantes, cantidades); las fechas siguen atadas a
# datetime.now() mas abajo, asi que se corren con la fecha de generacion.
SEMILLA = 42
random.seed(SEMILLA)
np.random.seed(SEMILLA)


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


df_productos = pd.DataFrame({
    'id_producto': [1, 2],
    'nombre': ['Pegasus 40', 'Ultraboost'],
    'descripcion': ['Running neutra', 'Running retorno energia'],
    'precio_venta_actual': [150000.0, 175000.0],
    'id_marca': [1, 2],
    'id_categoria': [1, 1]
})


#En este modulo se generan los datos de la tabla producto_variante y movimientos
print("Generando Producto_Variante (Cross Join)...")

#Aca se hace un cross join entre productos, talles y colores para generar todas las combinaciones posibles // Esto crea la tabla Producto_Variante
df_temp1 = df_productos[['id_producto']].merge(df_talles[['id_talle']], how='cross')
df_variantes = df_temp1.merge(df_colores[['id_color']], how='cross')

# Aca se genera el codigo de barras, vasado en id_variante
df_variantes['id_variante'] = range(1, len(df_variantes) + 1)
df_variantes['codigo_barras'] = df_variantes['id_variante'].apply(lambda x: f"779{x:09d}")

# Reordenamos las columnas
df_variantes = df_variantes[['id_variante', 'id_producto', 'id_talle', 'id_color', 'codigo_barras']]


#Aca se generan los movimientos transaccionales y sus detalles
#Unicamente moviendo la cantidad de movimientos podemos generar un archivo SQL masivo para poblar la base de datos
#Obviamente debemos tener en cuenta que al inicio de la base de datos debemos tener cargados los catalogos y semidependientes
#para que los movimientos tengan sentido
print("Generando Movimientos transaccionales...")
CANTIDAD_MOVIMIENTOS = 1000

# Los ids 1 y 2 quedan reservados para los movimientos de apertura de inventario
# (uno por sucursal), que se arman mas abajo y van primeros en el archivo.
ID_PRIMER_MOVIMIENTO = 3

movimientos_list = []
detalle_list = []
id_detalle = 1

# Aca se generan fechas aleatorias entre el 1 de enero de 2025 y la fecha actual
def random_date(start_date, end_date):
    delta = end_date - start_date
    random_seconds = random.randrange(int(delta.total_seconds()))
    return start_date + timedelta(seconds=random_seconds)

inicio = datetime(2025, 1, 1)
fin = datetime.now()

for i in range(ID_PRIMER_MOVIMIENTO, ID_PRIMER_MOVIMIENTO + CANTIDAD_MOVIMIENTOS):
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
    
    # Aca se generar los detalles de cada movimiento
    cant_detalles = random.randint(1, 5)
    for _ in range(cant_detalles):
        variante = random.choice(df_variantes['id_variante'].tolist())
        cantidad = random.randint(1, 20)
        precio = random.choice(df_productos['precio_venta_actual'].tolist()) * random.uniform(0.7, 1.0) # Precio con posible descuento
        detalle_list.append([i, variante, cantidad, round(precio, 2)])
        id_detalle += 1

df_movimientos = pd.DataFrame(movimientos_list, columns=['id_movimiento', 'fecha_hora', 'tipo_movimiento', 'observaciones', 'id_empleado', 'id_sucursal_origen', 'id_sucursal_destino'])
df_detalle = pd.DataFrame(detalle_list, columns=['id_movimiento', 'id_variante', 'cantidad', 'precio_unitario'])


df_detalle['id_movimiento'] = df_detalle['id_movimiento'].astype(int)
df_detalle['id_variante'] = df_detalle['id_variante'].astype(int)
df_detalle['cantidad'] = df_detalle['cantidad'].astype(int)


# ==============================================================================
# APERTURA DE INVENTARIO Y CALCULO DEL STOCK
# ==============================================================================
# La carga masiva se ejecuta antes que 07_Funciones_Procedimientos.sql, asi que
# durante la carga los triggers todavia no existen y nadie calcula el stock: la
# tabla Inventario quedaba vacia. Lo calculamos aca a mano, con la misma
# semantica que fn_actualizar_inventario_por_movimiento:
#
#   Entrada  -> suma  en id_sucursal_origen  (en una entrada, origen es la
#               sucursal que RECIBE; asi lo hace sp_registrar_entrada_mercaderia)
#   Salida   -> resta en id_sucursal_origen
#   Traslado -> resta en id_sucursal_origen y suma en id_sucursal_destino
#
# El problema es que los movimientos se sortean al azar, sin la nocion de que no
# se puede vender lo que no entro: recorriendolos en orden cronologico, casi
# todas las celdas (sucursal, variante) pasan por saldo negativo en algun punto,
# y chk_stock_positivo rechazaria esas filas.
#
# La solucion es una apertura: un movimiento de Entrada por sucursal, fechado
# antes de todo el historico, con un renglon por variante y la cantidad justa
# para cubrir el peor bajon de esa celda, mas un colchon. Con eso el saldo nunca
# queda negativo, ni al final ni en el camino, y el Inventario que se inserta es
# exactamente el que producirian los triggers si se reprodujeran los movimientos
# uno por uno.
print("Calculando saldos y apertura de inventario...")

FECHA_APERTURA = '2024-12-31 08:00:00'
COLCHON_MINIMO = 5     # unidades por encima del peor bajon de cada celda
COLCHON_MAXIMO = 45

detalles_por_movimiento = defaultdict(list)
for id_mov, variante, cantidad, _precio in detalle_list:
    detalles_por_movimiento[id_mov].append((variante, cantidad))

saldo = defaultdict(int)       # saldo corriente de cada (sucursal, variante)
peor_saldo = defaultdict(int)  # punto mas bajo por el que paso ese saldo


def registrar_saldo(celda, delta):
    saldo[celda] += delta
    if saldo[celda] < peor_saldo[celda]:
        peor_saldo[celda] = saldo[celda]


# El orden de insercion (por id) no es el orden cronologico, y para saber si el
# stock alcanzaba en cada momento hay que recorrer por fecha.
for mov in sorted(movimientos_list, key=lambda m: m[1]):
    id_mov, _fecha, tipo, _obs, _emp, origen, destino = mov
    for variante, cantidad in detalles_por_movimiento[id_mov]:
        if tipo == 'Entrada':
            registrar_saldo((origen, variante), cantidad)
        elif tipo == 'Salida':
            registrar_saldo((origen, variante), -cantidad)
        else:
            registrar_saldo((origen, variante), -cantidad)
            registrar_saldo((destino, variante), cantidad)

producto_de_variante = dict(zip(df_variantes['id_variante'], df_variantes['id_producto']))
precio_de_producto = dict(zip(df_productos['id_producto'], df_productos['precio_venta_actual']))
id_empleado_deposito = df_empleados['id_empleado'].iloc[0]

apertura_mov_list = []
apertura_det_list = []
inventario_list = []

for id_apertura, id_sucursal in enumerate(df_sucursales['id_sucursal'].tolist(), start=1):
    apertura_mov_list.append([
        id_apertura, FECHA_APERTURA, 'Entrada',
        'Apertura de inventario generada por script Pandas',
        id_empleado_deposito, id_sucursal, 'NULL'
    ])
    for variante in df_variantes['id_variante'].tolist():
        celda = (id_sucursal, variante)
        faltante = -peor_saldo[celda]  # peor_saldo siempre es <= 0
        cantidad_apertura = faltante + random.randint(COLCHON_MINIMO, COLCHON_MAXIMO)
        # El costo de reposicion se estima en el 60 % del precio de venta. No
        # altera ninguna consulta del benchmark: todas suman importes filtrando
        # por tipo_movimiento = 'Salida', y esto es una Entrada.
        costo = round(precio_de_producto[producto_de_variante[variante]] * 0.6, 2)
        apertura_det_list.append([id_apertura, variante, cantidad_apertura, costo])
        inventario_list.append([id_sucursal, variante, cantidad_apertura + saldo[celda]])

df_apertura_mov = pd.DataFrame(apertura_mov_list, columns=df_movimientos.columns)
df_apertura_det = pd.DataFrame(apertura_det_list, columns=df_detalle.columns)
df_inventario = pd.DataFrame(inventario_list, columns=['id_sucursal', 'id_variante', 'cantidad_disponible'])

# Red de seguridad: si algo de lo de arriba se rompe, que se note al generar y
# no doce mil lineas de SQL despues, cuando falle el CHECK en PostgreSQL.
assert (df_inventario['cantidad_disponible'] >= 0).all(), "hay stock final negativo"
assert (df_apertura_det['cantidad'] > 0).all(), "hay una apertura con cantidad <= 0"



#Aca se exportan los dataframes a un archivo SQL
print("Exportando a Carga_Masiva.sql...")

def df_to_sql_insert(df, table_name):
    #Convierte un DataFrame de Pandas en sentencias INSERT de SQL
    sql_statements = f"\n-- Inserciones para {table_name}\n"
    # Se recorre con itertuples y no con iterrows porque iterrows arma una Serie
    # por fila y promueve todos los numeros a float64: los ids enteros salian
    # escritos como "1.0" en el SQL.
    for row in df.itertuples(index=False, name=None):
        values = []
        for val in row:
            if pd.isna(val) or val == 'NULL':
                values.append("NULL")
            elif isinstance(val, (int, np.integer, float, np.floating)):
                values.append(str(val))
            else:
                
                escaped_val = str(val).replace("'", "''")
                values.append(f"'{escaped_val}'")
        
        sql_statements += f"INSERT INTO {table_name} ({', '.join(df.columns)}) VALUES ({', '.join(values)});\n"
    return sql_statements

# Reposicionamos cada secuencia en MAX(id) + 1. El is_called en false hace que
# el proximo nextval devuelva exactamente ese valor.
SQL_SINCRONIZAR_SECUENCIAS = "\n-- Sincronizacion de las secuencias SERIAL\n" + "".join(
    f"SELECT setval(pg_get_serial_sequence('{tabla}', '{columna}'),"
    f" COALESCE((SELECT MAX({columna}) FROM {tabla}), 0) + 1, false);\n"
    for tabla, columna in [
        ('marcas', 'id_marca'),
        ('categorias', 'id_categoria'),
        ('talles', 'id_talle'),
        ('colores', 'id_color'),
        ('sucursales', 'id_sucursal'),
        ('proveedores', 'id_proveedor'),
        ('empleados', 'id_empleado'),
        ('productos', 'id_producto'),
        ('producto_variante', 'id_variante'),
        ('movimientos', 'id_movimiento'),
        ('detalle_movimientos', 'id_detalle'),
    ]
)

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
    # La apertura va primero: es el movimiento mas viejo y el que deja el stock
    # con el que despues operan los movimientos transaccionales.
    file.write("\n-- Apertura de inventario (una Entrada por sucursal)\n")
    file.write(df_to_sql_insert(df_apertura_mov, 'Movimientos'))
    file.write(df_to_sql_insert(df_movimientos, 'Movimientos'))
    # Suponiendo que el rombo [Contiene] se transformó en la tabla Detalle_Movimientos
    file.write(df_to_sql_insert(df_apertura_det, 'Detalle_Movimientos'))
    file.write(df_to_sql_insert(df_detalle, 'Detalle_Movimientos'))

    # Nivel 4: el stock resultante de aplicar todos los movimientos de arriba.
    file.write("\n-- Stock resultante de aplicar los movimientos anteriores\n")
    file.write(df_to_sql_insert(df_inventario, 'Inventario'))

    # Las columnas SERIAL no avanzan su secuencia cuando el id se inserta a mano,
    # asi que sin esto la secuencia sigue en 1 y el primer INSERT que delegue el
    # id (por ejemplo sp_registrar_venta_caja) choca con clave duplicada.
    file.write(SQL_SINCRONIZAR_SECUENCIAS)

print("¡Archivo Carga_Masiva.sql generado con éxito!")
print(f"  Movimientos: {len(df_apertura_mov) + len(df_movimientos)}"
      f" | Detalles: {len(df_apertura_det) + len(df_detalle)}"
      f" | Inventario: {len(df_inventario)} filas")
print(f"  Stock minimo: {df_inventario['cantidad_disponible'].min()}"
      f" | mediana: {int(df_inventario['cantidad_disponible'].median())}"
      f" | maximo: {df_inventario['cantidad_disponible'].max()}")
print(f"  Celdas con stock < 35 (las que devuelve la consulta 4):"
      f" {int((df_inventario['cantidad_disponible'] < 35).sum())}")