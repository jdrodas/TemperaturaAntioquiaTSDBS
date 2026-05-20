# Temperatura Antioquia 2023–2026

## Comparativo de Modelado de Bases de Datos para Series de Tiempo

## 📊 Descripción del proyecto

Este proyecto presenta un análisis comparativo de diferentes enfoques de modelado de bases de datos para el manejo de series de tiempo, desarrollado como parte de los cursos de Tópicos Avanzados de Bases de datos y Bases de datos No Estructuradas.

El estudio evoluciona desde un modelo relacional tradicional hacia implementaciones especializadas, evaluando las consideraciones de diseño, ventajas y desventajas de cada aproximación.

Los datos originales fueron tomados de la Plataforma Nacional de Datos Abiertos de Colombia, del dataset denominado

**Datos Hidrometeorológicos Crudos - Red de Estaciones IDEAM : Temperatura**

[https://www.datos.gov.co/Ambiente-y-Desarrollo-Sostenible/Datos-Hidrometeorol-gicos-Crudos-Red-de-Estaciones/sbwg-7ju4/about_data](https://www.datos.gov.co/Ambiente-y-Desarrollo-Sostenible/Datos-Hidrometeorol-gicos-Crudos-Red-de-Estaciones/sbwg-7ju4/about_data)

Filtros aplicados:

- **Departamento**: Antioquia
- **Rango fechas**: Enero 1 de 2023, 12:00 am a Marzo 31 de 2026, 11:59 pm.
- **Total registros estimados (tras ampliación del rango)**: ~2.000.000 filas.

**Importante**: Los datos aquí expuestos son utilizados con fines académicos. Por favor acceda al recurso relacionado para conocer más información al respecto.

---

## 🎯 Objetivos del Proyecto

1. **Diseñar** modelos de datos apropiados para series de tiempo en cada tecnología
2. **Implementar** esquemas y consultas representativas del dominio
3. **Analizar** las consideraciones de diseño específicas de cada aproximación
4. **Comparar** rendimiento, escalabilidad y complejidad de implementación con ~2 millones de registros
5. **Documentar** ventajas y desventajas de cada solución
6. **Explorar** la calidad de los datos crudos mediante EDA antes de la carga

---

## 🌡️ Dominio del problema

El caso de estudio se centra en un sistema de **monitoreo de temperatura ambiente** con las siguientes características:

- **Múltiples estaciones de medición** distribuidas en diferentes municipios del departamento de Antioquia
- **Período de análisis**: Enero 2023 – Marzo 2026 (~3 años)
- **Frecuencia de medición**: Aproximadamente cada 15 minutos
- **Datos temporales**: Timestamps precisos para cada medición

La ampliación del rango a tres años permite realizar análisis estacionales por épocas climáticas y meses, enriqueciendo el estudio con patrones de largo plazo típicos de un entorno IoT de monitoreo ambiental.

Este dominio es ideal para evaluar bases de datos de series de tiempo debido a:

- Alto volumen de inserciones secuenciales (~2 millones de registros)
- Patrones de consulta basados en rangos temporales
- Necesidad de agregaciones y análisis estadísticos
- Importancia de la eficiencia en almacenamiento
- Análisis estacional y detección de tendencias multianuales

---

## 📁 Estructura del dataset

Cada registro en el archivo fuente (CSV exportado desde datos.gov.co) solo contiene las siguientes columnas:

| Columna           | Tipo sugerido     | Descripción                                                                 |
|-------------------|-------------------|-----------------------------------------------------------------------------|
| `CodigoEstacion`  | `VARCHAR` / `TEXT` | Identificador único de la estación de medición                             |
| `CodigoSensor`    | `VARCHAR` / `TEXT` | Código del sensor asociado a la medición (ej. `0068`, `0071`)             |
| `FechaObservacion`| `TIMESTAMP`        | Fecha y hora de la medición (formato: `YYYY Mon DD HH:MM:SS AM/PM`)        |
| `ValorObservado`  | `FLOAT` / `DOUBLE` | Temperatura registrada en grados Celsius (usa coma como separador decimal) |
| `NombreEstacion`  | `VARCHAR` / `TEXT` | Nombre descriptivo de la estación meteorológica                            |
| `Municipio`       | `VARCHAR` / `TEXT` | Municipio donde se ubica la estación                                       |
| `ZonaHidrografica`| `VARCHAR` / `TEXT` | Zona hidrográfica a la que pertenece la estación (ej. `NECHÍ`, `CAUCA`)   |
| `NombreVariable`  | `VARCHAR` / `TEXT` | Descripción de la variable medida (ej. `TEMPERATURA DEL AIRE A 2 m`)      |

**Nota sobre calidad de datos**: Los datos crudos presentan problemas típicos de fuentes IoT:   
- valores faltantes
- registros duplicados   
- inconsistencias en el formato de fecha y hora
- valores atípicos. 
 
El Notebook de EDA (ver sección correspondiente) documenta y trata estos problemas.

---

## 🗄️ Tecnologías Evaluadas

### 1. PostgreSQL (Modelo Relacional)

Implementación tradicional usando un modelo relacional normalizado. Sirve como línea base para comparar el rendimiento y complejidad del diseño con las soluciones especializadas.

**Directorio**: `/postgresql`

### 2. TimescaleDB

Extensión de PostgreSQL optimizada para series de tiempo. Mantiene la compatibilidad con SQL mientras introduce capacidades específicas como hypertables y compresión automática.

**Directorio**: `/timescaledb`

### 3. MongoDB

Base de datos orientada a documentos que permite flexibilidad en el esquema y almacenamiento de datos jerárquicos. Evaluación de cómo un modelo NoSQL maneja series de tiempo.

**Directorio**: `/mongodb`

### 4. InfluxDB

Base de datos especializada en series de tiempo con un modelo de datos optimizado para métricas, eventos y análisis temporal.

**Directorio**: `/influxdb`

### 5. ClickHouse

Base de datos OLAP orientada a columnas, diseñada para análisis de grandes volúmenes de datos con consultas de alta velocidad sobre agregaciones. Su arquitectura columnar la hace especialmente eficiente para cargas de trabajo analíticas sobre series de tiempo, como el cálculo de promedios, máximos y mínimos sobre millones de registros.

**Directorio**: `/clickhouse`

---

## 🔬 Análisis Exploratorio de Datos (EDA)

Como paso previo a la carga en cualquier motor de base de datos, se incluye un Jupyter Notebook de EDA que permite entender la estructura, calidad y características del dataset crudo.

**Directorio**: `/eda`  
**Archivo principal**: [`eda_temperatura_antioquia.ipynb`](https://github.com/jdrodas/TemperaturaAntioquiaTSDBS/blob/main/eda/eda_temperatura_antioquia.ipynb)

### Contenido esperado del Notebook

El notebook cubre las siguientes etapas:

1. **Carga e inspección inicial**
   - Lectura del modelo de datos relacional en base de datos PostgreSQL
   - Revisión de tipos de datos, forma del dataset y primeras filas

2. **Análisis de calidad de datos**
   - Detección de valores nulos y registros incompletos
   - Identificación de duplicados (misma estación, mismo timestamp)
   - Validación del rango de fechas y consistencia del período
   - Revisión de formatos: separador decimal (coma vs punto), formato de timestamp

3. **Análisis de valores atípicos**
   - Distribución de `ValorObservado` por estación y municipio
   - Detección de outliers (temperaturas físicamente improbables)
   - Visualización de boxplots y series temporales por estación

4. **Exploración temporal**
   - Frecuencia real de muestreo (¿cada cuánto llegan los registros?)
   - Gaps o interrupciones en la serie temporal por estación
   - Análisis estacional: comparación por mes y por año (2023–2026)

5. **Análisis por dimensiones geográficas**
   - Distribución de estaciones por municipio y zona hidrográfica
   - Comparación de temperaturas medias entre zonas

6. **Conclusiones y recomendaciones de limpieza**
   - Resumen de problemas encontrados
   - Decisiones de preprocesamiento aplicadas antes de la carga a cada motor


---

## 🔍 Aspectos Evaluados

- **Modelado de datos**: Estrategias de esquema y normalización
- **Operaciones de escritura**: Inserción masiva y rendimiento
- **Consultas temporales**: Rangos de tiempo, agregaciones, downsampling
- **Compresión y almacenamiento**: Eficiencia en el uso de espacio
- **Mantenimiento**: Particionamiento, retención de datos, optimización
- **Escalabilidad**: Comportamiento con volúmenes crecientes de datos
- **Análisis estacional**: Tendencias multianuales (2023–2026)

---

## 📝 Consultas a implementar

Cada motor de base de datos deberá incluir las siguientes consultas representativas:

1. Temperatura promedio por estación en un rango de fechas
2. Temperaturas máximas y mínimas diarias por municipio
3. Tendencias mensuales de temperatura
4. Detección de anomalías (valores fuera de rangos normales)
5. Agregaciones por ventanas de tiempo (por hora, por día)
6. Comparativas entre estaciones de diferentes municipios
7. *(nuevo)* Análisis estacional: comparación del mismo mes entre diferentes años

---

## 📚 Recursos Adicionales

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [MongoDB Time Series Collections](https://www.mongodb.com/docs/manual/core/timeseries-collections/)
- [InfluxDB Documentation](https://docs.influxdata.com/)
- [ClickHouse Documentation](https://clickhouse.com/docs/en/intro)
- [Jupyter Notebook Documentation](https://jupyter-notebook.readthedocs.io/en/stable/)
- [Datos Abiertos Colombia – IDEAM Temperatura](https://www.datos.gov.co/Ambiente-y-Desarrollo-Sostenible/Datos-Hidrometeorol-gicos-Crudos-Red-de-Estaciones/sbwg-7ju4/about_data)
