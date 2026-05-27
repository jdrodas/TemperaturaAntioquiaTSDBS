-- Scripts de clase - Mayo de 2026
-- Juan Dario Rodas - jdrodas@hotmail.com

-- Proyecto: Analisis de Temperatura en Antioquia para el año 2024 y 2026
-- Motor de Base de datos: PostgreSQL 18.x
-- Version: Relacional - Extensión de TimescaleDB

-- *******************************************************
-- Consultas SQL con enfoque en la perspectiva temporal
-- *******************************************************

-- ********************************************************
-- Superbásicas:
-- ********************************************************

-- Rango temporal de los datos
-- Fecha de primera y última observación
-- Desde 01/01/2025 hasta 30/09/2025 debe dar
-- 0 years 0 mons 272 days 23 hours 58 mins 0.0 secs
SELECT
    MIN(fecha) fecha_inicial,
    MAX(fecha) fecha_final,
    (MAX(fecha) - MIN(fecha)) periodo_total
FROM observaciones;

-- Número de observaciones por estación ubicada en municipio
SELECT
    e.nombre  estacion_nombre,
    m.nombre  municipio_nombre,
    COUNT(*)  total_observaciones,
    MIN(o.fecha)  fecha_inicio,
    MAX(o.fecha)  fecha_final
FROM observaciones o
    JOIN estaciones e ON o.estacion_id = e.id
    JOIN municipios m ON e.municipio_id = m.id
GROUP BY e.nombre, m.nombre
ORDER BY municipio_nombre, total_observaciones desc, estacion_nombre;


-- ============================================================
-- Continuous Aggregate: Temperaturas Diarias por Estación
-- ============================================================

CREATE MATERIALIZED VIEW mv_temperaturas_diarias
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', fecha) AS dia,
    estacion_id,
    sensor_id,
    round(AVG(valor)::numeric,2) AS temp_promedio,
    MAX(valor) AS temp_maxima,
    MIN(valor) AS temp_minima,
    round(STDDEV(valor)::numeric,2) AS temp_desviacion,
    COUNT(*) AS num_observaciones,
    -- Primer y última observación del día
    FIRST(valor, fecha) AS primera_lectura,
    LAST(valor, fecha) AS ultima_lectura
FROM observaciones
GROUP BY dia, estacion_id, sensor_id;


-- Política de refresh: 
-- actualizar datos de los últimos 7 días, dejando 1 hora de margen
SELECT add_continuous_aggregate_policy('mv_temperaturas_diarias',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');



-- =============================================================
-- Continuous Aggregate: Temperaturas Mensuales por Estación
-- =============================================================

CREATE MATERIALIZED VIEW mv_temperaturas_mensuales
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 month', fecha) AS mes,
    estacion_id,
    sensor_id,
    round(AVG(valor)::numeric,2) AS temp_promedio,
    MAX(valor) AS temp_maxima,
    MIN(valor) AS temp_minima,
    round(STDDEV(valor)::numeric,2) AS temp_desviacion,
    round((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY valor))::numeric,2) AS temp_mediana,
    COUNT(*) AS num_observaciones
FROM observaciones
GROUP BY mes, estacion_id, sensor_id;

COMMENT ON VIEW mv_temperaturas_mensuales IS 'Continuous Aggregate: Agregación mensual de temperaturas por estación y sensor';

-- Política de refresh: actualizar datos de los últimos 3 meses cada 12 horas
SELECT add_continuous_aggregate_policy('mv_temperaturas_mensuales',
    start_offset => INTERVAL '3 months',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '12 hours');

SELECT
    mes,
    estacion_id,
    temp_promedio,
    temp_maxima,
    temp_minima,
    temp_mediana,
FROM mv_temperaturas_mensuales
ORDER BY mes DESC
LIMIT 10;

-- =========================================================
-- Continuous Aggregate: Temperaturas Diarias por Municipio
-- =========================================================

CREATE MATERIALIZED VIEW mv_temperaturas_municipios_diarias
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', o.fecha) AS dia,
    e.municipio_id,
    m.nombre municipio_nombre,
    round(AVG(o.valor)::numeric,2) AS temp_promedio,
    MAX(o.valor) AS temp_maxima,
    MIN(o.valor) AS temp_minima,
    round(STDDEV(o.valor)::numeric,2) AS temp_desviacion,
    COUNT(*) AS num_observaciones,
    COUNT(DISTINCT o.estacion_id) AS num_estaciones
FROM observaciones o
JOIN estaciones e ON o.estacion_id = e.id
JOIN municipios m on e.municipio_id = m.id
GROUP BY dia, e.municipio_id,m.nombre;

COMMENT ON VIEW mv_temperaturas_municipios_diarias IS 'Continuous Aggregate: Agregación diaria de temperaturas por municipio';

-- Política de refresh: actualizar datos de los últimos 7 días cada hora
SELECT add_continuous_aggregate_policy('mv_temperaturas_municipios_diarias',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

-- Ver todos los continuous aggregates
SELECT * FROM timescaledb_information.continuous_aggregates;
