from datetime import date, datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

# ==============================================================================
# PARAMETROS
# ==============================================================================
# Todo lo que define la forma y la escala del dataset esta aca. El resto del
# archivo no tiene numeros incrustados.

# Semilla fija y fechas fijas: dos corridas producen CSVs identicos byte a byte.
# Con datetime.now() el rango del sorteo de fechas cambiaba segundo a segundo.
SEMILLA = 42

DIR_DATOS = Path(__file__).resolve().parent
DIR_GENERADO = DIR_DATOS / 'generado'
ARCHIVO_PRODUCTOS = DIR_GENERADO / 'productos_masivos.csv'

# --- Escala -------------------------------------------------------------------
CANTIDAD_MOVIMIENTOS = 500_000

# Proporcion de cada tipo de movimiento. En una cadena de retail la enorme
# mayoria de las operaciones son ventas.
MEZCLA_TIPOS = {'Salida': 0.75, 'Entrada': 0.125, 'Traslado': 0.125}

# Renglones de detalle por movimiento, (minimo, maximo) inclusive. Con la mezcla
# de arriba dan en promedio unos tres renglones por movimiento.
RENGLONES_POR_MOVIMIENTO = {'Salida': (1, 3), 'Entrada': (4, 12), 'Traslado': (2, 6)}

# Unidades por renglon, (minimo, maximo) inclusive. Las de Entrada estan
# calibradas para que lo que ingresa a cada celda (sucursal, variante) acompañe
# lo que se vende: 750.000 renglones de venta por 1,5 unidades contra 500.000
# de entrada por 2,5. Si ingresara mucho menos, la apertura tendria que cubrir
# casi todas las ventas del periodo; si ingresara mucho mas, el stock crece sin
# techo.
UNIDADES_POR_RENGLON = {'Salida': (1, 2), 'Entrada': (1, 4), 'Traslado': (1, 3)}

# --- Periodo --------------------------------------------------------------------
FECHA_INICIO_HISTORIAL = date(2025, 1, 1)
FECHA_FIN_HISTORIAL = date(2026, 9, 14)   # inclusive
HORARIO_ATENCION = (9, 21)                # los movimientos caen entre estas horas
FECHA_APERTURA = datetime(2024, 12, 31, 8, 0, 0)

# --- Popularidad ----------------------------------------------------------------
# Las ventas no se reparten parejo: a cada producto se le asigna un puesto al
# azar en un ranking y su peso es 1 / (puesto + DESPLAZAMIENTO) ** EXPONENTE
# (Zipf-Mandelbrot). Eso deja una cola larga de productos que casi no se venden,
# que es lo que hace que la consulta 2 tenga algo que encontrar. El
# desplazamiento aplana la cabeza: con Zipf puro el producto mas vendido se
# llevaba el 13 % de todas las unidades.
EXPONENTE_POPULARIDAD = 1.0
DESPLAZAMIENTO_POPULARIDAD = 20

# Dentro de un producto, los talles del medio y los colores neutros venden mas.
PESO_TALLE = {
    'S': 0.15, 'M': 0.30, 'L': 0.30, 'XL': 0.17, 'XXL': 0.08,
    '39': 0.10, '40': 0.17, '41': 0.22, '42': 0.22, '43': 0.17, '44': 0.12,
    'Único': 1.00,
}
PESO_COLOR = {'Negro': 0.40, 'Blanco': 0.25, 'Gris': 0.20, 'Azul': 0.15}

# --- Precios --------------------------------------------------------------------
# Las ventas salen al precio de lista con un descuento sorteado en este rango
# (1.0 = sin descuento). Entradas y traslados se valorizan al costo.
FACTOR_PRECIO_VENTA = (0.70, 1.00)
PROPORCION_COSTO = 0.60

# --- Apertura de inventario -----------------------------------------------------
# Unidades por encima del peor bajon de cada celda (ver mas abajo).
COLCHON_APERTURA = (2, 10)

# --- Catalogos --------------------------------------------------------------------
# Que talles aplican a cada categoria. El esquema no lo restringe (no hay una
# tabla de talles validos por categoria), asi que se resuelve por convencion
# aca. Tiene que cubrir todas las categorias del CSV de productos.
TALLES_ROPA = ['S', 'M', 'L', 'XL', 'XXL']
TALLES_POR_CATEGORIA = {
    'Remeras': TALLES_ROPA,
    'Tops': TALLES_ROPA,
    'Shorts': TALLES_ROPA,
    'Calzas': TALLES_ROPA,
    'Pantalones': TALLES_ROPA,
    'Buzos': TALLES_ROPA,
    'Camperas': TALLES_ROPA,
    'Zapatillas': ['39', '40', '41', '42', '43', '44'],
    'Medias': ['Único'],
}

COLORES = list(PESO_COLOR)

# Un proveedor por marca: cada Entrada trae mercaderia de una sola marca.
PROVEEDOR_POR_MARCA = {
    'Nike':         ('Nike Argentina S.A.',         '30-71000001-1', '11-4321-1001', 'ventas@nike.com.ar'),
    'Adidas':       ('Adidas Argentina S.A.',       '30-71000002-2', '11-4321-1002', 'ventas@adidas.com.ar'),
    'Puma':         ('Puma Sports Argentina S.A.',  '30-71000003-3', '11-4321-1003', 'ventas@puma.com.ar'),
    'Under Armour': ('Under Armour Argentina S.A.', '30-71000004-4', '11-4321-1004', 'ventas@underarmour.com.ar'),
}

# Las dos primeras conservan id y nombre del dataset original: la consulta 3
# filtra por 'Sucursal NOA' y 08_Concurrencia.sql opera sobre la sucursal 1.
SUCURSALES = [
    ('Central CABA',            'Av. Corrientes 3200',   'Buenos Aires'),
    ('Sucursal NOA',            'Rivadavia 550',         'Catamarca'),
    ('Sucursal Córdoba',        'Av. Colón 1200',        'Córdoba'),
    ('Sucursal Rosario',        'Córdoba 1450',          'Rosario'),
    ('Sucursal Mendoza',        'Av. San Martín 900',    'Mendoza'),
    ('Sucursal Mar del Plata',  'Güemes 2800',           'Mar del Plata'),
    ('Sucursal Tucumán',        '24 de Septiembre 600',  'San Miguel de Tucumán'),
    ('Sucursal Neuquén',        'Av. Argentina 300',     'Neuquén'),
]

# Empleados es independiente de Sucursales en el modelo. El generador igual le
# asigna a cada empleado una sucursal propia, y solo registra movimientos en
# ella, para que agrupar por empleado dentro de una sucursal tenga sentido. El
# primero de cada sucursal es el Administrador y firma la apertura.
EMPLEADOS_POR_SUCURSAL = 5
DOCUMENTO_MINIMO, DOCUMENTO_MAXIMO = 20_000_000, 45_000_000
NOMBRES = ['Carlos', 'Laura', 'Martín', 'Sofía', 'Lucas', 'Valentina', 'Diego', 'Camila',
           'Juan', 'Florencia', 'Matías', 'Agustina', 'Nicolás', 'Julieta', 'Federico', 'Paula']
APELLIDOS = ['Gómez', 'Díaz', 'Pérez', 'Rodríguez', 'Fernández', 'López', 'Martínez', 'García',
             'Sánchez', 'Romero', 'Sosa', 'Álvarez', 'Torres', 'Ruiz', 'Ramírez', 'Acosta']

OBSERVACIONES = {
    'Salida': 'Venta en caja',
    'Entrada': 'Reposición de proveedor',
    'Traslado': 'Traslado entre sucursales',
}
OBSERVACION_APERTURA = 'Apertura de inventario'

PREFIJO_CODIGO_BARRAS = '779'

rng = np.random.default_rng(SEMILLA)


def ids(n):
    return np.arange(1, n + 1)


# ==============================================================================
# CATALOGOS Y PRODUCTOS
# ==============================================================================
print("Leyendo catalogo de productos...")
if not ARCHIVO_PRODUCTOS.exists():
    raise SystemExit(f"No existe {ARCHIVO_PRODUCTOS}. Correr antes: python generar_masivos.py")

df_csv = pd.read_csv(ARCHIVO_PRODUCTOS)

marcas_desconocidas = set(df_csv['marca']) - set(PROVEEDOR_POR_MARCA)
categorias_desconocidas = set(df_csv['categoria']) - set(TALLES_POR_CATEGORIA)
if marcas_desconocidas or categorias_desconocidas:
    raise SystemExit(f"El CSV de productos trae marcas {marcas_desconocidas or '{}'} y categorias"
                     f" {categorias_desconocidas or '{}'} que este generador no conoce")

df_marcas = pd.DataFrame({'id_marca': ids(len(PROVEEDOR_POR_MARCA)), 'nombre': list(PROVEEDOR_POR_MARCA)})
df_categorias = pd.DataFrame({'id_categoria': ids(len(TALLES_POR_CATEGORIA)), 'nombre': list(TALLES_POR_CATEGORIA)})
df_talles = pd.DataFrame({'id_talle': ids(len(PESO_TALLE)), 'nomenclatura': list(PESO_TALLE)})
df_colores = pd.DataFrame({'id_color': ids(len(COLORES)), 'nombre_color': COLORES})

id_marca = dict(zip(df_marcas['nombre'], df_marcas['id_marca']))
id_categoria = dict(zip(df_categorias['nombre'], df_categorias['id_categoria']))
id_talle = dict(zip(df_talles['nomenclatura'], df_talles['id_talle']))

df_sucursales = pd.DataFrame(SUCURSALES, columns=['nombre', 'direccion', 'ciudad'])
df_sucursales.insert(0, 'id_sucursal', ids(len(SUCURSALES)))
CANTIDAD_SUCURSALES = len(df_sucursales)

df_proveedores = pd.DataFrame(list(PROVEEDOR_POR_MARCA.values()),
                              columns=['razon_social', 'cuit', 'telefono', 'email'])
df_proveedores.insert(0, 'id_proveedor', ids(len(df_proveedores)))
# Mismo orden que df_marcas: el proveedor de la marca i es el i.

cantidad_empleados = CANTIDAD_SUCURSALES * EMPLEADOS_POR_SUCURSAL
df_empleados = pd.DataFrame({
    'id_empleado': ids(cantidad_empleados),
    'documento': rng.choice(np.arange(DOCUMENTO_MINIMO, DOCUMENTO_MAXIMO), cantidad_empleados,
                            replace=False).astype(str),
    'nombre': rng.choice(NOMBRES, cantidad_empleados),
    'apellido': rng.choice(APELLIDOS, cantidad_empleados),
    'perfil_acceso': np.where(np.arange(cantidad_empleados) % EMPLEADOS_POR_SUCURSAL == 0,
                              'Administrador', 'Operativo'),
})

df_productos = pd.DataFrame({
    'id_producto': ids(len(df_csv)),
    'nombre': df_csv['nombre'],
    'descripcion': df_csv['descripcion'],
    'precio_venta_actual': df_csv['precio_venta_actual'],
    'id_marca': df_csv['marca'].map(id_marca),
    'id_categoria': df_csv['categoria'].map(id_categoria),
})


# ==============================================================================
# VARIANTES
# ==============================================================================
# Cada producto se cruza solo con los talles de su categoria, y con todos los
# colores.
print("Generando Producto_Variante...")

df_talles_categoria = pd.DataFrame(
    [(id_categoria[cat], id_talle[t]) for cat, talles in TALLES_POR_CATEGORIA.items() for t in talles],
    columns=['id_categoria', 'id_talle'])

df_variantes = (df_productos[['id_producto', 'id_categoria']]
                .merge(df_talles_categoria, on='id_categoria')
                .merge(df_colores[['id_color']], how='cross')
                .sort_values(['id_producto', 'id_talle', 'id_color'], kind='stable')
                .reset_index(drop=True))
df_variantes.insert(0, 'id_variante', ids(len(df_variantes)))
df_variantes['codigo_barras'] = [f"{PREFIJO_CODIGO_BARRAS}{v:09d}" for v in df_variantes['id_variante']]
df_variantes = df_variantes[['id_variante', 'id_producto', 'id_talle', 'id_color', 'codigo_barras']]
CANTIDAD_VARIANTES = len(df_variantes)

# Arreglos indexados por posicion de variante (id_variante - 1)
producto_de_variante = df_variantes['id_producto'].to_numpy()
precio_de_variante = df_productos['precio_venta_actual'].to_numpy()[producto_de_variante - 1]
marca_de_variante = df_productos['id_marca'].to_numpy()[producto_de_variante - 1]

# Peso de venta de cada variante: popularidad del producto por peso del talle
# (normalizado dentro de su categoria) por peso del color.
puesto_producto = rng.permutation(len(df_productos)) + 1
peso_producto = 1.0 / (puesto_producto + DESPLAZAMIENTO_POPULARIDAD) ** EXPONENTE_POPULARIDAD

peso_talle_en_categoria = {}
for cat, talles in TALLES_POR_CATEGORIA.items():
    total = sum(PESO_TALLE[t] for t in talles)
    for t in talles:
        peso_talle_en_categoria[(id_categoria[cat], id_talle[t])] = PESO_TALLE[t] / total

categoria_de_variante = df_productos['id_categoria'].to_numpy()[producto_de_variante - 1]
peso_variante = (peso_producto[producto_de_variante - 1]
                 * np.array([peso_talle_en_categoria[(c, t)]
                             for c, t in zip(categoria_de_variante, df_variantes['id_talle'])])
                 * df_variantes['id_color'].map(dict(zip(df_colores['id_color'], PESO_COLOR.values()))).to_numpy())
prob_variante = peso_variante / peso_variante.sum()


# ==============================================================================
# MOVIMIENTOS
# ==============================================================================
print("Generando Movimientos...")

# Las fechas se sortean y se ordenan antes de asignar ids, asi el orden de los
# ids coincide con el cronologico, como pasaria con un SERIAL en produccion.
dias_historial = (FECHA_FIN_HISTORIAL - FECHA_INICIO_HISTORIAL).days + 1
hora_desde, hora_hasta = HORARIO_ATENCION
segundos = np.sort(
    rng.integers(0, dias_historial, CANTIDAD_MOVIMIENTOS) * 86_400
    + hora_desde * 3_600
    + rng.integers(0, (hora_hasta - hora_desde) * 3_600, CANTIDAD_MOVIMIENTOS))
fechas = np.datetime64(FECHA_INICIO_HISTORIAL, 's') + segundos.astype('timedelta64[s]')

tipos_posibles = np.array(list(MEZCLA_TIPOS))
tipo = rng.choice(tipos_posibles, CANTIDAD_MOVIMIENTOS, p=list(MEZCLA_TIPOS.values()))
es_salida, es_entrada, es_traslado = (tipo == 'Salida'), (tipo == 'Entrada'), (tipo == 'Traslado')

origen = rng.integers(1, CANTIDAD_SUCURSALES + 1, CANTIDAD_MOVIMIENTOS)
# Destino distinto del origen, uniforme entre las demas sucursales
destino = (origen - 1 + rng.integers(1, CANTIDAD_SUCURSALES, CANTIDAD_MOVIMIENTOS)) % CANTIDAD_SUCURSALES + 1
empleado = (origen - 1) * EMPLEADOS_POR_SUCURSAL + rng.integers(1, EMPLEADOS_POR_SUCURSAL + 1, CANTIDAD_MOVIMIENTOS)

# Cada Entrada trae una sola marca, elegida en proporcion a lo que se vende de ella
prob_marca = np.bincount(marca_de_variante, weights=prob_variante, minlength=len(df_marcas) + 1)[1:]
marca_entrada = rng.choice(df_marcas['id_marca'].to_numpy(), CANTIDAD_MOVIMIENTOS, p=prob_marca)

# Los ids 1..CANTIDAD_SUCURSALES quedan para las aperturas
id_movimiento = CANTIDAD_SUCURSALES + ids(CANTIDAD_MOVIMIENTOS)

df_movimientos = pd.DataFrame({
    'id_movimiento': id_movimiento,
    'fecha_hora': pd.Series(fechas).dt.strftime('%Y-%m-%d %H:%M:%S'),
    'tipo_movimiento': tipo,
    'observaciones': pd.Series(tipo).map(OBSERVACIONES),
    'id_sucursal_origen': origen,
    'id_sucursal_destino': pd.array(np.where(es_traslado, destino, 0), dtype='Int64'),
    'id_empleado': empleado,
    'id_proveedor': pd.array(np.where(es_entrada, marca_entrada, 0), dtype='Int64'),
})
df_movimientos.loc[~es_traslado, 'id_sucursal_destino'] = pd.NA
df_movimientos.loc[~es_entrada, 'id_proveedor'] = pd.NA


# ==============================================================================
# DETALLE DE MOVIMIENTOS
# ==============================================================================
print("Generando Detalle_Movimientos...")

renglones = np.zeros(CANTIDAD_MOVIMIENTOS, dtype=np.int64)
for t, (minimo, maximo) in RENGLONES_POR_MOVIMIENTO.items():
    mascara = tipo == t
    renglones[mascara] = rng.integers(minimo, maximo + 1, mascara.sum())

mov_de_renglon = np.repeat(np.arange(CANTIDAD_MOVIMIENTOS), renglones)
tipo_renglon = tipo[mov_de_renglon]
cantidad_renglones = len(mov_de_renglon)

# Ventas y traslados eligen variantes segun la popularidad; las entradas, segun
# la popularidad dentro de la marca que trae el proveedor.
variante_idx = np.empty(cantidad_renglones, dtype=np.int64)
no_entrada = tipo_renglon != 'Entrada'
variante_idx[no_entrada] = rng.choice(CANTIDAD_VARIANTES, no_entrada.sum(), p=prob_variante)
marca_renglon = marca_entrada[mov_de_renglon]
for m in df_marcas['id_marca']:
    mascara = (tipo_renglon == 'Entrada') & (marca_renglon == m)
    de_la_marca = np.flatnonzero(marca_de_variante == m)
    p = prob_variante[de_la_marca] / prob_variante[de_la_marca].sum()
    variante_idx[mascara] = rng.choice(de_la_marca, mascara.sum(), p=p)

cantidad = np.zeros(cantidad_renglones, dtype=np.int64)
for t, (minimo, maximo) in UNIDADES_POR_RENGLON.items():
    mascara = tipo_renglon == t
    cantidad[mascara] = rng.integers(minimo, maximo + 1, mascara.sum())

factor_venta = rng.uniform(*FACTOR_PRECIO_VENTA, cantidad_renglones)
precio = np.round(np.where(tipo_renglon == 'Salida',
                           precio_de_variante[variante_idx] * factor_venta,
                           precio_de_variante[variante_idx] * PROPORCION_COSTO), 2)


# ==============================================================================
# APERTURA DE INVENTARIO Y CALCULO DEL STOCK
# ==============================================================================
# La carga masiva se ejecuta antes que 07_Funciones_Procedimientos.sql, asi que
# durante la carga los triggers todavia no existen y nadie calcula el stock. Lo
# calculamos aca, con la misma semantica que fn_actualizar_inventario_por_movimiento:
#
#   Entrada  -> suma  en id_sucursal_origen  (en una entrada, origen es la
#               sucursal que RECIBE; asi lo hace sp_registrar_entrada_mercaderia)
#   Salida   -> resta en id_sucursal_origen
#   Traslado -> resta en id_sucursal_origen y suma en id_sucursal_destino
#
# Los movimientos se sortean sin la nocion de que no se puede vender lo que no
# entro, asi que recorriendolos en orden cronologico muchas celdas (sucursal,
# variante) pasan por saldo negativo en algun punto, y chk_stock_positivo
# rechazaria esas filas.
#
# La solucion es una apertura: un movimiento de Entrada por sucursal, fechado
# antes de todo el historico, con un renglon por variante y la cantidad justa
# para cubrir el peor bajon de esa celda, mas un colchon. Con eso el saldo nunca
# queda negativo, ni al final ni en el camino, y el Inventario que se escribe es
# exactamente el que producirian los triggers si se reprodujeran los movimientos
# en orden de id.
print("Calculando saldos y apertura de inventario...")

# Los renglones de la apertura van primero, asi que los del historial arrancan
# despues. Como los ids de movimiento siguen el orden cronologico, el id de
# detalle ordena cronologicamente.
cantidad_renglones_apertura = CANTIDAD_SUCURSALES * CANTIDAD_VARIANTES
id_detalle = cantidad_renglones_apertura + ids(cantidad_renglones)

origen_renglon = origen[mov_de_renglon]
signo = np.where(tipo_renglon == 'Entrada', 1, -1)
traslado_renglon = tipo_renglon == 'Traslado'


def celda(sucursal, idx_variante):
    return (sucursal - 1) * CANTIDAD_VARIANTES + idx_variante


# Un delta por renglon en la sucursal de origen, y uno mas por cada traslado en
# la de destino.
deltas = pd.DataFrame({
    'celda': np.concatenate([celda(origen_renglon, variante_idx),
                             celda(destino[mov_de_renglon][traslado_renglon], variante_idx[traslado_renglon])]),
    'orden': np.concatenate([id_detalle, id_detalle[traslado_renglon]]),
    'delta': np.concatenate([signo * cantidad, cantidad[traslado_renglon]]),
}).sort_values(['celda', 'orden'], kind='stable')
deltas['saldo'] = deltas.groupby('celda')['delta'].cumsum()
por_celda = deltas.groupby('celda').agg(peor=('saldo', 'min'), neto=('delta', 'sum'))

cantidad_celdas = CANTIDAD_SUCURSALES * CANTIDAD_VARIANTES
peor_saldo = np.zeros(cantidad_celdas, dtype=np.int64)
neto = np.zeros(cantidad_celdas, dtype=np.int64)
peor_saldo[por_celda.index] = np.minimum(por_celda['peor'].to_numpy(), 0)
neto[por_celda.index] = por_celda['neto'].to_numpy()

cantidad_apertura = -peor_saldo + rng.integers(COLCHON_APERTURA[0], COLCHON_APERTURA[1] + 1, cantidad_celdas)
stock_final = cantidad_apertura + neto

sucursal_de_celda = np.repeat(df_sucursales['id_sucursal'].to_numpy(), CANTIDAD_VARIANTES)
variante_de_celda = np.tile(df_variantes['id_variante'].to_numpy(), CANTIDAD_SUCURSALES)

df_apertura_mov = pd.DataFrame({
    'id_movimiento': df_sucursales['id_sucursal'],
    'fecha_hora': FECHA_APERTURA.strftime('%Y-%m-%d %H:%M:%S'),
    'tipo_movimiento': 'Entrada',
    'observaciones': OBSERVACION_APERTURA,
    'id_sucursal_origen': df_sucursales['id_sucursal'],
    'id_sucursal_destino': pd.array([pd.NA] * CANTIDAD_SUCURSALES, dtype='Int64'),
    'id_empleado': (df_sucursales['id_sucursal'] - 1) * EMPLEADOS_POR_SUCURSAL + 1,
    'id_proveedor': pd.array([pd.NA] * CANTIDAD_SUCURSALES, dtype='Int64'),
})

# El costo de la apertura es el mismo PROPORCION_COSTO de las entradas. No altera
# ninguna consulta del benchmark: todas suman importes de Salidas.
df_detalle = pd.DataFrame({
    'id_detalle': np.concatenate([ids(cantidad_renglones_apertura), id_detalle]),
    'cantidad': np.concatenate([cantidad_apertura, cantidad]),
    'precio_unitario': np.concatenate([
        np.round(precio_de_variante[variante_de_celda - 1] * PROPORCION_COSTO, 2), precio]),
    'id_movimiento': np.concatenate([sucursal_de_celda, id_movimiento[mov_de_renglon]]),
    'id_variante': np.concatenate([variante_de_celda, variante_idx + 1]),
})

df_movimientos = pd.concat([df_apertura_mov, df_movimientos], ignore_index=True)

df_inventario = pd.DataFrame({
    'id_sucursal': sucursal_de_celda,
    'id_variante': variante_de_celda,
    'cantidad_disponible': stock_final,
})

# Red de seguridad: si algo de lo de arriba se rompe, que se note al generar y
# no al final de la carga, cuando falle el CHECK en PostgreSQL.
assert (df_inventario['cantidad_disponible'] >= 0).all(), "hay stock final negativo"
assert (df_detalle['cantidad'] > 0).all(), "hay un renglon con cantidad <= 0"
assert df_detalle['id_detalle'].is_unique and df_movimientos['id_movimiento'].is_unique


# ==============================================================================
# EXPORTACION
# ==============================================================================
# Un CSV por tabla. Carga_Masiva.sql los carga con \copy en orden de dependencias.
print("Exportando CSVs a generado/...")

TABLAS = [
    ('marcas', df_marcas),
    ('categorias', df_categorias),
    ('talles', df_talles),
    ('colores', df_colores),
    ('sucursales', df_sucursales),
    ('proveedores', df_proveedores),
    ('empleados', df_empleados),
    ('productos', df_productos),
    ('producto_variante', df_variantes),
    ('movimientos', df_movimientos),
    ('detalle_movimientos', df_detalle),
    ('inventario', df_inventario),
]

DIR_GENERADO.mkdir(exist_ok=True)
for nombre, df in TABLAS:
    df.to_csv(DIR_GENERADO / f"{nombre}.csv", index=False, encoding='utf-8', float_format='%.2f')

salidas = df_detalle[df_movimientos.set_index('id_movimiento')
                     .loc[df_detalle['id_movimiento'], 'tipo_movimiento'].to_numpy() == 'Salida']
unidades_vendidas = salidas['cantidad'].sum()
stock = df_inventario['cantidad_disponible']

print("CSVs generados en generado/")
print(f"  Productos: {len(df_productos)} | Variantes: {CANTIDAD_VARIANTES}"
      f" | Sucursales: {CANTIDAD_SUCURSALES} | Empleados: {len(df_empleados)}")
print(f"  Movimientos: {len(df_movimientos)} | Detalles: {len(df_detalle)}"
      f" | Inventario: {len(df_inventario)} filas")
print(f"  Stock minimo: {stock.min()} | mediana: {int(stock.median())}"
      f" | p95: {int(stock.quantile(0.95))} | maximo: {stock.max()}")
print(f"  Precio promedio por unidad vendida: {(salidas['cantidad'] * salidas['precio_unitario']).sum() / unidades_vendidas:,.0f}")
