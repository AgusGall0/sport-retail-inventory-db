import pandas as pd
import random

# Definimos las bases para armar los nombres
prendas = ['Remera', 'Pantalón', 'Short', 'Campera', 'Zapatillas', 'Buzo', 'Top', 'Calza', 'Medias']
adjetivos = ['Pro', 'Elite', 'Basic', 'Training', 'Ultra', 'Tech', 'Aeroswift', 'Dry-Fit', 'Compression']
marcas = [1, 2, 3] # Asumiendo que tenés 3 marcas cargadas
categorias = [1, 2, 3, 4, 5] # Asumiendo que tenés 5 categorías

# Generamos 1000 productos aleatorios pero con sentido lógico
datos_masivos = []
for i in range(1000):
    nombre = f"{random.choice(prendas)} {random.choice(adjetivos)} v{random.randint(1,99)}"
    descripcion = f"Indumentaria deportiva serie {i} para alto rendimiento."
    precio = round(random.uniform(15000, 150000), 2)
    
    datos_masivos.append({
        'nombre': nombre,
        'descripcion': descripcion,
        'precio_venta_actual': precio,
        'id_marca': random.choice(marcas),
        'id_categoria': random.choice(categorias)
    })

# Creamos el DataFrame con Pandas
df_productos = pd.DataFrame(datos_masivos)

# Exportamos a un archivo CSV limpio
df_productos.to_csv('productos_masivos.csv', index=False, encoding='utf-8')

print("¡Éxito! Se generó el archivo 'productos_masivos.csv' con 1000 productos.")