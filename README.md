

#Enlace al docs 
https://docs.google.com/document/d/1K4unwIwHwI8RXNYgObpo2TEBqA3vqclmPD6TWJiCMDw/edit?usp=sharing


# Proyecto Integrador BD - Arquitectura y Gestión de Datos Masivos para Stock Deportivo

## Descripción General del Proyecto

El presente repositorio documenta el diseño, desarrollo e implementación integral de un sistema de bases de datos relacionales basado en **PostgreSQL**. Este proyecto fue concebido para resolver la compleja logística y administración de inventario de una cadena comercial dedicada a la venta de indumentaria deportiva.

Más allá del modelado inicial de datos, el objetivo de este desarrollo es simular y gestionar un ecosistema productivo real. El sistema está preparado para soportar el ciclo de vida completo de la información comercial: desde el ingreso de mercadería a través de proveedores, hasta la distribución, traslado y venta final en múltiples sucursales físicas. 

Para lograr esto, la arquitectura del proyecto evolucionó a través de cinco etapas fundamentales de la ingeniería de datos, garantizando no solo el almacenamiento, sino el rendimiento, la seguridad y la consistencia transaccional.

## Alcance y Fases del Desarrollo

### 1. Arquitectura Base y Calidad de la Información
El cimiento del sistema es un modelo relacional estrictamente normalizado hasta la **Tercera Forma Normal (3FN)**. Para abordar el desafío particular del rubro textil, se implementó un diseño granular que separa el "producto conceptual" del "artículo físico" . Esto permite administrar el stock con precisión milimétrica, considerando combinaciones únicas de productos, talles y colores. La integridad de la información está blindada en el motor de la base de datos mediante restricciones de dominio y políticas de integridad referencial, asegurando que el historial logístico y contable sea inmutable frente a errores humanos.

### 2. Escalabilidad y Simulación de Entornos Productivos
Un sistema de datos no puede evaluarse únicamente en vacío. Por ello, el proyecto incluye estrategias de carga masiva de datos diseñadas para poblar las tablas transaccionales con un volumen significativo de registros. Esta etapa simula el paso del tiempo y la operatoria diaria de la empresa, permitiendo evaluar cómo se comporta la estructura cuando el volumen de información crece exponencialmente, tal como ocurre en los ambientes empresariales reales.

### 3. Ingeniería de Rendimiento (Tuning y Optimización)
Para transformar los datos en información útil para la toma de decisiones, se desarrolló un módulo de consultas avanzadas orientadas a la generación de reportes complejos. Ante el desafío del gran volumen de datos introducido en la etapa anterior, se aplicaron técnicas de *tuning* y optimización. Esto incluye la creación estratégica de índices y el análisis profundo del planificador de tareas de PostgreSQL (utilizando herramientas como `EXPLAIN ANALYZE`), logrando reducir drásticamente los tiempos de respuesta del servidor.

### 4. Capa de Seguridad y Control de Acceso (RBAC)
Entendiendo que la información comercial es un activo crítico, el sistema incorpora un robusto esquema de seguridad basado en roles (Role-Based Access Control). Se definieron perfiles de acceso estructurados (Administración, Operatoria y Consulta) bajo el principio de mínimo privilegio. Además, se implementó un sistema de vistas diseñado para simplificar las consultas de los usuarios finales y, fundamentalmente, para enmascarar u ocultar la información sensible según el nivel de autorización de quien consulta.

### 5. Lógica de Negocio y Concurrencia Transaccional
La última capa del proyecto traslada la inteligencia del negocio directamente al servidor de base de datos a través de la programabilidad con **PL/pgSQL**. Se desarrollaron procedimientos y funciones almacenadas para automatizar operaciones críticas. Finalmente, el sistema fue sometido a escenarios de concurrencia, implementando un estricto manejo de transacciones (con sentencias `COMMIT` y `ROLLBACK`) para prevenir colisiones, bloqueos o corrupción de datos cuando múltiples usuarios operan y modifican el inventario de manera simultánea.

---

## Equipo de Desarrollo
*   **Juan Agustin Gallo** (MU: 01731)
*   **Escalante Judith Griselda** (MU: 01862)
*   **Bravo Nicolass** (MU: 01805)
*   **Pongan sus nombres aca** (MU: sus matriculas aca)
