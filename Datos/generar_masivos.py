import random
from pathlib import Path

import pandas as pd

# ==============================================================================
# PARAMETROS
# ==============================================================================
# Semilla fija: el CSV no se versiona, se regenera, y generador_datos.py lo lee.
# Sin semilla cada corrida daria otro catalogo y el dataset dejaria de ser
# reproducible.
SEMILLA = 42

CANTIDAD_PRODUCTOS = 1000

ARCHIVO_SALIDA = Path(__file__).resolve().parent / 'generado' / 'productos_masivos.csv'

MARCAS = ['Nike', 'Adidas', 'Puma', 'Under Armour']

# Cada prenda define su categoria y el rango de precio de venta, en pesos
# argentinos. La categoria se deriva de la prenda para que el nombre y la
# clasificacion no se contradigan ("Zapatillas" nunca cae en "Remeras").
PRENDAS = {
    'Remera':     {'categoria': 'Remeras',    'precio': (15_000, 40_000)},
    'Top':        {'categoria': 'Tops',       'precio': (15_000, 35_000)},
    'Short':      {'categoria': 'Shorts',     'precio': (18_000, 45_000)},
    'Calza':      {'categoria': 'Calzas',     'precio': (25_000, 60_000)},
    'Pantalón':   {'categoria': 'Pantalones', 'precio': (35_000, 90_000)},
    'Buzo':       {'categoria': 'Buzos',      'precio': (45_000, 110_000)},
    'Campera':    {'categoria': 'Camperas',   'precio': (60_000, 180_000)},
    'Zapatillas': {'categoria': 'Zapatillas', 'precio': (80_000, 250_000)},
    'Medias':     {'categoria': 'Medias',     'precio': (5_000, 15_000)},
}

LINEAS = ['Pro', 'Elite', 'Basic', 'Training', 'Ultra', 'Tech', 'Aeroswift', 'Dry-Fit', 'Compression']
VERSION_MAXIMA = 99

# Los precios de lista se redondean a la centena, como en una vidriera real.
REDONDEO_PRECIO = 100

# ==============================================================================
# GENERACION
# ==============================================================================
rng = random.Random(SEMILLA)

datos_masivos = []
for i in range(CANTIDAD_PRODUCTOS):
    prenda = rng.choice(list(PRENDAS))
    categoria = PRENDAS[prenda]['categoria']
    precio_minimo, precio_maximo = PRENDAS[prenda]['precio']
    precio = round(rng.uniform(precio_minimo, precio_maximo) / REDONDEO_PRECIO) * REDONDEO_PRECIO

    datos_masivos.append({
        'nombre': f"{prenda} {rng.choice(LINEAS)} v{rng.randint(1, VERSION_MAXIMA)}",
        'descripcion': f"Indumentaria deportiva, categoria {categoria}, serie {i}.",
        'precio_venta_actual': float(precio),
        'marca': rng.choice(MARCAS),
        'categoria': categoria,
    })

df_productos = pd.DataFrame(datos_masivos)

ARCHIVO_SALIDA.parent.mkdir(exist_ok=True)
df_productos.to_csv(ARCHIVO_SALIDA, index=False, encoding='utf-8', float_format='%.2f')

print(f"Se genero generado/{ARCHIVO_SALIDA.name} con {len(df_productos)} productos.")
