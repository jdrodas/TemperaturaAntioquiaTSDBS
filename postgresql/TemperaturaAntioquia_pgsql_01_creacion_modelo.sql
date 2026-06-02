-- Scripts de clase - Junio de 2026
-- Juan Dario Rodas - jdrodas@hotmail.com

-- Proyecto: Analisis de Temperatura en Antioquia para el año 2024 y 2026
-- Motor de Base de datos: PostgreSQL 18.x
-- Version: Relacional

-- ***********************************
-- Abastecimiento de imagen en Docker
-- ***********************************

-- Descargar la imagen
docker pull postgres:latest

-- Crear el contenedor
docker run --name tempant-pgsql -e POSTGRES_PASSWORD=unaClav3 -d -p 5432:5432 postgres:latest

-- ***********************************
-- Abastecimiento de datos
-- ***********************************

/*
Temperatura Antioquia 2024-2026
Análisis de la temperatura para el departamento de Antioquia en el 2024-2026, 
usando diferentes tecnologías de almacenamiento de datos.

Los datos originales fueron tomados de la Plataforma Nacional de Datos 
Abiertos de Colombia, del dataset denominado

Datos Hidrometeorológicos Crudos - Red de Estaciones IDEAM : Temperatura

https://www.datos.gov.co/Ambiente-y-Desarrollo-Sostenible/Datos-Hidrometeorol-gicos-Crudos-Red-de-Estaciones/sbwg-7ju4/about_data

Filtros aplicados:

Departamento: Antioquia
Rango fechas: Abril 1 de 2024, 12:00 am a Mayo 31 2026, 11:58 pm.
Total registros iniciales antes de control de calidad: -- 1'546.662

Importante:
Los datos aqui expuestos son utilizados con fines académicos. 
Por favor acceda al recurso relacionado para conocer más información al respecto.
*/

-- ****************************************
-- Creación de base de datos y usuarios
-- ****************************************

-- Con usuario Root:

-- crear el esquema la base de datos
create database tempant_db;

-- Conectarse a la base de datos
\c tempant_db;

-- crear el usuario con el que se realizarán las acciones
create user tempant_usr with encrypted password 'unaClav3';

-- asignación de privilegios para el usuario
-- ==========================================

-- Privilegios para establecer conexiones
grant connect on database tempant_db to tempant_usr;

-- privilegios para crear tablas temporales
grant temporary on database tempant_db to tempant_usr;

-- Privilegios de uso en el esquema
grant usage on schema public to tempant_usr;

-- privilegios para crear objetos
grant create on schema public to tempant_usr;

-- Privilegios sobre tablas existentes
grant select, insert, update, delete, trigger on all tables in schema public to tempant_usr;

-- privilegios sobre secuencias existentes
grant usage, select on all sequences in schema public to tempant_usr;

-- privilegios sobre funciones existentes
grant execute on all functions in schema public to tempant_usr;

-- privilegios sobre procedimientos existentes
grant execute on all procedures in schema public to tempant_usr;

-- privilegios sobre futuras tablas y secuencias
alter default privileges in schema public grant select, insert, update, delete, trigger on tables to tempant_usr;

alter default privileges in schema public grant select, usage on sequences to tempant_usr;

-- privilegios sobre futuras funciones y procedimientos
alter default privileges in schema public grant execute on routines to tempant_usr;

--Privilegios de consulta sobre el esquema information_schema
grant usage on schema information_schema to tempant_usr;

-- =========================================
-- crear el usuario de solo consulta
-- =========================================

create user tempant_qry with encrypted password 'unaClav3';

-- asignación de privilegios para el usuario
grant connect on database tempant_db to tempant_qry;
grant usage on schema public to tempant_qry;

-- Privilegios sobre tablas existentes
grant select on all tables in schema public to tempant_qry;

-- privilegios sobre secuencias existentes
grant usage, select on all sequences in schema public to tempant_qry;

-- privilegios sobre funciones existentes
grant execute on all functions in schema public to tempant_qry;

-- privilegios sobre procedimientos existentes
grant execute on all procedures in schema public to tempant_qry;

-- privilegios sobre objetos futuros
alter default privileges in schema public grant select on tables TO tempant_qry;
alter default privileges in schema public grant execute on routines to tempant_qry;

-- =========================================
-- Para validar los privilegios sobre tablas
-- =========================================
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'tempant_usr';

-- Para validar los privilegios sobre los esquemas
SELECT 
    n.nspname AS schema_name,
    CASE WHEN has_schema_privilege('tempant_usr', n.oid, 'CREATE') THEN 'CREATE' ELSE NULL END AS create_privilege,
    CASE WHEN has_schema_privilege('tempant_usr', n.oid, 'USAGE') THEN 'USAGE' ELSE NULL END AS usage_privilege
FROM 
    pg_catalog.pg_namespace n
WHERE 
    n.nspname NOT LIKE 'pg_%'
    AND n.nspname != 'information_schema';


-- Para validar los atributos del usuario
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin
FROM pg_roles
WHERE rolname = 'tempant_usr';

-- Para validar privilegios a nivel de base de datos
SELECT grantee, privilege_type
FROM information_schema.usage_privileges
WHERE object_type = 'DATABASE' AND object_name = 'tempant_db';

-- Para validar privilegios sobre rutinas
SELECT grantee, routine_schema, routine_name, privilege_type
FROM information_schema.routine_privileges
WHERE grantee = 'tempant_usr';

-- Para validar privilegios sobre secuencias
select grantee, object_schema, object_name, 
object_type, privilege_type 
FROM information_schema.usage_privileges
WHERE grantee = 'tempant_usr'
AND object_type = 'SEQUENCE';

-- =====================================
-- Cargue de datos iniciales 
-- =====================================

-- Tabla datos temporales
create table datos_temporales
(
    codigoestacion      text,    
    codigosensor        text,
    fechaobservacion    text,
    valorobservado      text,
    nombreestacion      text,
    departamento        text,
    municipio           text,
    zonahidrografica    text,
    latitud             text,
    longitud            text,
    descripcionsensor   text,
    UnidadMedida        text
);

-- ===========================================
-- Depuración de inconsistencias en datos de
-- estaciones
-- ===========================================

-- Unicidad de estaciones
select distinct codigoestacion,
                count(distinct nombreestacion) total_nombres
from datos_temporales
group by codigoestacion
having count(distinct nombreestacion)>1;

-- Estación con nombre duplicado: 0027015330
select distinct codigoestacion,nombreestacion
from datos_temporales
where codigoestacion = '0027015330'
order by codigoestacion;

update datos_temporales
set nombreestacion = 'AEROPUERTO OLAYA HERRERA'
where codigoestacion = '0027015330';

-- Unicidad de coordenadas geográficas
select distinct
    codigoestacion,
    nombreestacion,
    count(distinct latitud) total_latitudes
from datos_temporales
group by
    codigoestacion,
    nombreestacion
having count(distinct latitud) > 1;

select distinct
    codigoestacion,
    nombreestacion,
    count(distinct longitud) total_longitudes
from datos_temporales
group by
    codigoestacion,
    nombreestacion
having count(distinct longitud) > 1;

/*
Estaciones identificadas con problema de coordenadas:

0023085270  AEROPUERTO J.M. CORDOVA
0027015330  AEROPUERTO OLAYA HERRERA
0026185020  MESOPOTAMIA
*/

update datos_temporales
set latitud = '6,1686111', longitud = '-75,42611111'
where codigoestacion = '0023085270';

update datos_temporales
set latitud = '5,88636111', longitud = '-75,31863889'
where codigoestacion = '0026185020';

update datos_temporales
set latitud = '6,2246389', longitud = '-75,588225'
where codigoestacion = '0027015330';

-- =====================================
-- Creación de tablas del modelo
-- =====================================

-- Tabla: Departamentos
create table departamentos
(
    id              integer generated always as identity constraint departamentos_pk primary key,
    nombre          text not null constraint nombre_departamento_uk unique
);

comment on table departamentos is 'Departamentos de Colombia';
comment on column departamentos.id is 'Id del departamento';
comment on column departamentos.nombre is 'Nombre del departamento';


-- Tabla: zonas
create table zonas
(
    id              integer generated always as identity constraint zonas_pk primary key,
    nombre          text not null constraint nombre_zona_uk unique
);

comment on table zonas is 'Zonas Hidrográficas de Colombia';
comment on column zonas.id is 'Id de la zona';
comment on column zonas.nombre is 'Nombre de la zona';

-- Tabla: Municipios
create table municipios
(
    id              integer generated always as identity constraint municipios_pk primary key,
    nombre          text not null,
    departamento_id integer not null constraint municipios_departamentos_fk references departamentos,
    zona_id         integer not null constraint municipios_zonas_fk references zonas (id),
    constraint nombre_municipio_en_departamento_uk unique (nombre, departamento_id)
);

comment on table municipios is 'Municipios de Colombia ubicados en departamentos y zonas hidrográficas';
comment on column municipios.id is 'Id del municipio';
comment on column municipios.nombre is 'nombre del municipio';
comment on column municipios.departamento_id is 'Id del departamento al que pertenece el municipio';
comment on column municipios.zona_id is 'Id de la zona hidrográfica donde está ubicado el municipio';

-- Tabla: Estaciones
create table estaciones
(
    id              text not null constraint estaciones_pk primary key,
    nombre          text not null,
    municipio_id    integer not null constraint estaciones_municipios_fk references municipios,
    latitud         double precision not null,
    longitud        double precision not null,
    constraint coordenadas_estacion_uk unique(latitud,longitud)
);

alter table estaciones add constraint estaciones_nombre_uk unique (nombre);
create index idx_estaciones_lower_nombre ON estaciones (lower(nombre));

comment on table estaciones is 'Estaciones de Medición de Temperatura';
comment on column estaciones.id is 'Id de la estación';
comment on column estaciones.nombre is 'nombre de la estación';
comment on column estaciones.municipio_id is 'Id del municipio donde está la estación';
comment on column estaciones.latitud is 'Componente latitud de la coordenada geográfica de la estación';
comment on column estaciones.longitud is 'Componente longitud de la coordenada geográfica de la estación';

-- Tabla: Observaciones
create table observaciones
(
    id              integer generated always as identity constraint observaciones_pk primary key,
    estacion_id     text not null constraint observaciones_estaciones_fk references estaciones,
    valor           float not null,
    fecha           timestamp without time zone not null 
);

comment on table observaciones is 'Observaciones de temperatura realizadas por las estaciones';
comment on column observaciones.id is 'Id de la observación';
comment on column observaciones.estacion_id is 'Id de la estación que hizo la observación';
comment on column observaciones.valor is 'valor de temperatura obtenido en la observación';
comment on column observaciones.fecha is 'fecha en la que se realizó la la observación de temperatura';

create index concurrently idx_obs_estacion_sensor_fecha
    ON observaciones (estacion_id, fecha);

-- ===========================================
-- Cargue de datos desde la tabla provisional 
-- ===========================================

-- Departamentos
insert into departamentos (nombre)
select distinct departamento
from datos_temporales;

-- Creación de indice
create index idx_departamentos_lower_nombre ON departamentos (lower(nombre));

-- Devolver el Id generado a la tabla provisional
alter table datos_temporales add column departamento_id int;

update datos_temporales dt
set departamento_id = d.id
from departamentos d
where dt.departamento_id is null
and lower(d.nombre) = lower(dt.departamento);

-- Zonas 
insert into zonas (nombre)
select distinct ZonaHidrografica from datos_temporales;

-- Creación de indice
create index idx_zonas_lower_nombre ON zonas (lower(nombre));

-- Devolver el Id generado a la tabla provisional
alter table datos_temporales add column zona_id int;

update datos_temporales dt
set zona_id = z.id
from zonas z
where dt.zona_id is null
and lower(z.nombre) = lower(dt.ZonaHidrografica);


-- Municipios
insert into municipios (nombre, departamento_id, zona_id)
select distinct municipio, departamento_id, zona_id
from datos_temporales
order by zona_id, municipio;

-- Creación de indice
create index idx_municipios_lower_nombre ON municipios (lower(nombre));

-- Devolver el Id generado a la tabla provisional
alter table datos_temporales add column municipio_id int;

-- Devolver el Id generado a la tabla provisional
update datos_temporales dt
set municipio_id = m.id
from municipios m
where dt.municipio_id is null
and m.zona_id = dt.zona_id
and m.departamento_id = dt.departamento_id
and lower(m.nombre) = lower(dt.municipio);


-- Estaciones
insert into estaciones (id, nombre, municipio_id,latitud,longitud)
select distinct
    codigoestacion,
    nombreestacion,
    municipio_id,
    replace(latitud,',','.')::double precision latitud,
    replace(longitud,',','.')::double precision longitud
from datos_temporales;

-- Observaciones:
insert into observaciones (estacion_id, valor, fecha)
select distinct
    codigoestacion,
    replace(valorobservado,',','.')::double precision valor_medicion,
    to_timestamp(fechaobservacion::text, 'YYYY Mon DD HH12:MI:SS AM') fecha_medicion
from datos_temporales
order by to_timestamp(fechaobservacion::text, 'YYYY Mon DD HH12:MI:SS AM'), codigoestacion;


-- Agregar columna calculada persistida fecha_dia generada a partir de la fecha
alter table observaciones 
    add column fecha_dia date generated always as (fecha::date) stored;

create index idx_obs_estacion_fecha_dia
    on observaciones (estacion_id, fecha_dia);

create index concurrently idx_obs_fecha_dia
    ON observaciones (fecha_dia);    


-- ===========================================
-- Validación de rangos de tiempo procesados
-- ===========================================
-- Crudos
select
    min(to_timestamp(fechaobservacion::text, 'YYYY Mon DD HH12:MI:SS AM')) fecha_minima,
    max(to_timestamp(fechaobservacion::text, 'YYYY Mon DD HH12:MI:SS AM')) fecha_minima
from datos_temporales;

-- Normalizados
select
    min(fecha) fecha_minima,
    max(fecha) fecha_maxima
from observaciones;

-- ==========================================================
-- Validación de duplicados exactos eliminados al normalizar
-- ==========================================================

/*
Antes de normalizar: 1'546.662 registros
Después de normalizar: 1'300.461 registros

Duplicados exactos eliminados: 246.201 registros
*/


-- ===========================================
-- Creación de Vistas y Vistas Materializads
-- ===========================================

create view v_info_departamentos as
(
    select distinct
        d.id departamento_id,
        d.nombre departamento_nombre,
        count(distinct m.id) total_municipios,
        count(distinct e.id) total_estaciones
    from departamentos d
        join municipios m on d.id = m.departamento_id
        join estaciones e on m.id = e.municipio_id
    group by
        d.id,
        d.nombre
);

-- vista: v_info_zonas
create view v_info_zonas as
(
    select distinct
        z.id zona_id,
        z.nombre zona_nombre,
            count(distinct m.id) total_municipios,
            count(distinct e.id) total_estaciones
    from zonas z
            join municipios m on z.id = m.zona_id
            join estaciones e on m.id = e.municipio_id
    group by
        z.id,
        z.nombre
);

-- vista: v_info_estaciones
create view v_info_estaciones as
(
    select distinct
        e.id       estacion_id,
        e.nombre   estacion_nombre,
        e.latitud  estacion_latitud,
        e.longitud estacion_longitud,
        e.municipio_id,
        m.nombre   municipio_nombre,
        m.zona_id,
        z.nombre   zona_nombre,
        m.departamento_id,
        d.nombre   departamento_nombre
    from estaciones e
    join municipios m on e.municipio_id = m.id
    join zonas z on m.zona_id = z.id
    join departamentos d on m.departamento_id = d.id
);

-- Vista materializada: mv_inventario_geografico
create materialized view mv_inventario_geografico as
select
    e.id estacion_id,
    e.nombre estacion_nombre,
    e.latitud estacion_latitud,
    e.longitud estacion_longitud,
    m.id municipio_id,
    m.nombre municipio_nombre,
    z.id zona_id,
    z.nombre zona_nombre,
    d.id departamento_id,
    d.nombre departamento_nombre
from estaciones    e
join municipios    m on e.municipio_id     = m.id
join zonas         z on m.zona_id          = z.id
join departamentos d on m.departamento_id  = d.id;

create unique index idx_mv_inventario_geografico_estacion_id
    on mv_inventario_geografico (estacion_id);

create index idx_mv_inventario_geografico_municipio_id
    on mv_inventario_geografico (municipio_id);

create index idx_mv_inventario_geografico_departamento
    on mv_inventario_geografico (departamento_nombre);

create index idx_mv_inventario_geografico_zona
    on mv_inventario_geografico (zona_nombre);


-- Vista materializada: mv_resumen_diario
create materialized view mv_resumen_diario as
select
    o.estacion_id,
    o.fecha_dia dia,
    COUNT(*) num_observaciones,
    MIN(o.valor) temp_minima,
    MAX(o.valor) temp_maxima,
    AVG(o.valor) temp_promedio,
    STDDEV(o.valor) temp_stddev,
    PERCENTILE_CONT(0.25) within group (order by o.valor)  percentil_25,
    PERCENTILE_CONT(0.50) within group (order by o.valor)  mediana,
    PERCENTILE_CONT(0.75) within group (order by o.valor)  percentil_75,
    MIN(o.fecha) primera_obs_dia,
    MAX(o.fecha) ultima_obs_dia
FROM observaciones o
GROUP BY o.estacion_id, o.fecha_dia;

create unique index idx_mv_resumen_diario_unique
    on mv_resumen_diario (estacion_id, dia);

create index idx_mv_resumen_diario_dia
    on mv_resumen_diario (dia);

create index idx_mv_resumen_diario_estacion_dia
    on mv_resumen_diario (estacion_id, dia);


-- Vista materializada: mv_resumen_mensual
create materialized view mv_resumen_mensual as
select
    DATE_TRUNC('month', dia)  mes,
    estacion_id,
    dia,
    SUM(num_observaciones)   num_observaciones,
    MIN(temp_minima)         temp_minima,
    MAX(temp_maxima)         temp_maxima,
    ROUND(AVG(temp_promedio)::numeric, 4)  temp_promedio,
    ROUND(AVG(temp_stddev)::numeric, 4)    temp_stddev,
    ROUND(AVG(percentil_25)::numeric, 4)   percentil_25,
    ROUND(AVG(mediana)::numeric, 4)        mediana,
    ROUND(AVG(percentil_75)::numeric, 4)   percentil_75,
    COUNT(DISTINCT dia)                    dias_con_datos
from mv_resumen_diario
group by DATE_TRUNC('month', dia), estacion_id, dia;

create unique index idx_mv_resumen_mensual_unique
    on mv_resumen_mensual (estacion_id, mes,dia);

create index idx_mv_resumen_mensual_mes
    on mv_resumen_mensual (mes);

create index idx_mv_resumen_mensual_estacion_mes
    on mv_resumen_mensual (estacion_id, mes);    


-- Vista materializada: mv_intervalos
create materialized view mv_intervalos as
with obs_ordenadas as (
    select
        estacion_id,
        fecha,
        LAG(fecha) over (
            partition by estacion_id
            order by fecha
        ) as fecha_anterior
    from observaciones
)
select
    estacion_id,
    fecha_anterior intervalo_inicio,
    fecha intervalo_fin,
    EXTRACT(EPOCH from (fecha - fecha_anterior)) / 60.0 intervalo_minutos,
    EXTRACT(EPOCH from (fecha - fecha_anterior)) / 3600.0 intervalo_horas
from obs_ordenadas
where fecha_anterior is not null;

create index idx_mv_intervalos_estacion_inicio
    on mv_intervalos (estacion_id, intervalo_inicio);

create index idx_mv_intervalos_horas
    on mv_intervalos (intervalo_horas);


-- vista: v_gaps_resumen
create or replace view v_gaps_resumen as
SELECT
    i.estacion_id,
    COUNT(*)                                   num_gaps,
    ROUND(MIN(i.intervalo_horas)::numeric, 1)  gap_minimo_horas,
    ROUND(MAX(i.intervalo_horas)::numeric, 1)  gap_maximo_horas,
    ROUND(AVG(i.intervalo_horas)::numeric, 1)  gap_promedio_horas,
    ROUND(SUM(i.intervalo_horas)::numeric, 1)  total_horas_perdidas
FROM mv_intervalos i
WHERE i.intervalo_horas IS NOT NULL
GROUP BY i.estacion_id;

-- vista: v_intervalos_por_estacion
create or replace view v_intervalos_por_estacion as
SELECT
    i.estacion_id,
    COUNT(*)                                           num_intervalos,
    ROUND(MIN(i.intervalo_minutos)::numeric, 1)        intervalo_minimo_min,
    ROUND(MAX(i.intervalo_minutos)::numeric, 1)        intervalo_maximo_min,
    ROUND(AVG(i.intervalo_minutos)::numeric, 1)        intervalo_promedio_min,
    ROUND(
        PERCENTILE_CONT(0.50) WITHIN GROUP
        (ORDER BY i.intervalo_minutos)::numeric, 1
    )                                                  intervalo_mediana_min,
    ROUND(STDDEV(i.intervalo_minutos)::numeric, 1)     intervalo_stddev_min
FROM mv_intervalos i
WHERE i.intervalo_minutos IS NOT NULL
GROUP BY i.estacion_id;

-- vista: v_duplicados_exactos
create or replace view v_duplicados_exactos as
SELECT
    o.estacion_id,
    o.fecha,
    o.valor               temperatura,
    COUNT(*)              num_repeticiones
FROM observaciones o
GROUP BY
    o.estacion_id,
    o.fecha,
    o.valor
HAVING COUNT(*) > 1;


-- vista: v_cuasi_duplicados
create or replace view v_cuasi_duplicados AS
SELECT
    o.estacion_id,
    o.fecha                                 fecha_actual,
    o.valor                                 valor_actual,
    LEAD(o.fecha) OVER (
        PARTITION BY o.estacion_id
        ORDER BY o.fecha
    )                                       fecha_siguiente,
    LEAD(o.valor) OVER (
        PARTITION BY o.estacion_id
        ORDER BY o.fecha
    )                                       valor_siguiente
FROM observaciones o;

-- vista: v_stats_temperatura_por_estacion
create or replace view v_stats_temperatura_por_estacion as
SELECT
    d.estacion_id,
    COUNT(DISTINCT d.dia)                    dias_analizados,
    SUM(d.num_observaciones)                 total_observaciones,
    ROUND(MIN(d.temp_minima)::numeric, 2)    temp_minima,
    ROUND(MAX(d.temp_maxima)::numeric, 2)    temp_maxima,
    ROUND(AVG(d.temp_promedio)::numeric, 2)  temp_promedio,
    ROUND(AVG(d.temp_stddev)::numeric, 2)    temp_stddev,
    ROUND(AVG(d.percentil_25)::numeric, 2)   percentil_25,
    ROUND(AVG(d.mediana)::numeric, 2)        mediana,
    ROUND(AVG(d.percentil_75)::numeric, 2)   percentil_75,
    ROUND(
        (MAX(d.temp_maxima) - MIN(d.temp_minima))::numeric, 2
    )                                        rango_termico
FROM mv_resumen_diario d
GROUP BY d.estacion_id;

-- vista: v_outliers_fisicos
create or replace view v_outliers_fisicos AS
SELECT
    o.estacion_id,
    o.fecha,
    ROUND(o.valor::numeric, 2)  temperatura,
    CASE
        WHEN o.valor < -5.0  THEN 'Bajo límite físico'
        WHEN o.valor > 45.0  THEN 'Sobre límite físico'
        WHEN o.valor <  5.0  THEN 'Bajo rango normal'
        WHEN o.valor > 35.0  THEN 'Sobre rango normal'
    END                          tipo_outlier
FROM observaciones o
WHERE
       o.valor < -5.0
    OR o.valor > 45.0
    OR o.valor <  5.0
    OR o.valor > 35.0;

-- Vista materializada: mv_stats_iqr
create materialized view mv_stats_iqr as
select
    estacion_id,
    COUNT(distinct dia) dias_analizados,
    AVG(temp_promedio)  media,
    STDDEV(temp_promedio) desviacion,
    MIN(temp_minima)      temp_minima,
    MAX(temp_maxima)      temp_maxima,
    PERCENTILE_CONT(0.25) within group (order by temp_promedio) percentil_25,
    PERCENTILE_CONT(0.50) within group (order by temp_promedio) mediana,
    PERCENTILE_CONT(0.75) within group (order by temp_promedio) percentil_75,
    PERCENTILE_CONT(0.75) within group (order by temp_promedio) -
    PERCENTILE_CONT(0.25) within group (order by temp_promedio) iqr
from mv_resumen_diario
group by estacion_id;

-- Índice único requerido para REFRESH CONCURRENTLY
create unique index idx_mv_stats_iqr_unique
    on mv_stats_iqr (estacion_id);    


-- vista: v_outliers_iqr
create or replace view v_outliers_iqr AS
SELECT
    o.estacion_id,
    o.fecha,
    ROUND(o.valor::numeric, 2)                                  temperatura,
    ROUND(st.percentil_25::numeric, 2)                          percentil_25,
    ROUND(st.percentil_75::numeric, 2)                          percentil_75,
    ROUND(st.iqr::numeric, 2)                                   iqr,
    ROUND((st.percentil_25 - (1.5 * st.iqr))::numeric, 2)       limite_inferior,
    ROUND((st.percentil_75 + (1.5 * st.iqr))::numeric, 2)       limite_superior,
    CASE
        WHEN o.valor < st.percentil_25 - (1.5 * st.iqr)
            THEN 'Bajo límite IQR'
        WHEN o.valor > st.percentil_75 + (1.5 * st.iqr)
            THEN 'Sobre límite IQR'
    END                                                         tipo_outlier
FROM observaciones o
JOIN mv_stats_iqr st ON o.estacion_id = st.estacion_id
WHERE
       o.valor < st.percentil_25 - (1.5 * st.iqr)
    OR o.valor > st.percentil_75 + (1.5 * st.iqr);    

-- vista: v_outliers_zscore
create or replace view v_outliers_zscore AS
SELECT
    o.estacion_id,
    o.fecha,
    ROUND(o.valor::numeric, 2)                                          temperatura,
    ROUND(st.media::numeric, 2)                                         media_estacion,
    ROUND(st.desviacion::numeric, 2)                                    desviacion_estacion,
    ROUND(
        ((o.valor - st.media) / NULLIF(st.desviacion, 0))::numeric, 3
    )                                                                   zscore,
    CASE
        WHEN (o.valor - st.media) / NULLIF(st.desviacion, 0) >  3.0
            THEN 'Z-score superior'
        WHEN (o.valor - st.media) / NULLIF(st.desviacion, 0) < -3.0
            THEN 'Z-score inferior'
    END                                                                 tipo_outlier
FROM observaciones o
JOIN mv_stats_iqr st ON o.estacion_id = st.estacion_id
WHERE ABS(
    (o.valor - st.media) / NULLIF(st.desviacion, 0)
) > 3.0;

-- Vista: mv_gaps_por_estacion
create materialized view mv_gaps_por_estacion as
select
    estacion_id,
    COUNT(*) num_gaps,
    MIN(intervalo_horas) gap_minimo_horas,
    MAX(intervalo_horas) gap_maximo_horas,
    ROUND(
        AVG(intervalo_horas)::numeric, 2) gap_promedio_horas,
    ROUND(SUM(intervalo_horas)::numeric, 2) total_horas_perdidas
from mv_intervalos
where intervalo_horas > 3
group by estacion_id;

create unique index idx_mv_gaps_por_estacion_unique
    on mv_gaps_por_estacion (estacion_id);

-- vista: v_info_observacion
create or replace view v_info_observacion as
(
    select distinct
        o.id observacion_id,
        o.fecha observacion_fecha,
        o.valor observacion_valor,
        o.estacion_id,
        e.nombre estacion_nombre,
        e.municipio_id,
        m.nombre municipio_nombre,
        m.zona_id,
        z.nombre zona_nombre,
        m.departamento_id,
        d.nombre departamento_nombre
    from observaciones o
        inner join estaciones e on o.estacion_id = e.id
        inner join municipios m on e.municipio_id = m.id
        inner join zonas z on m.zona_id = z.id
        inner join departamentos d on m.departamento_id = d.id
);

-- vista: v_ubicacion_estacion
create or replace view v_ubicacion_estacion as
(
    select distinct
        e.id estacion_id,
        e.nombre estacion_nombre,
        e.municipio_id,
        m.nombre municipio_nombre,
        m.zona_id,
        zh.nombre zona_nombre,
        m.departamento_id,
        d.nombre departamento_nombre
    from estaciones e
        inner join municipios m on e.municipio_id = m.id
        inner join zonas zh on m.zona_id = zh.id
        inner join departamentos d on m.departamento_id = d.id
);    

-- ===========================================
-- Consultas de exportacion de datos
-- ===========================================

-- Departamentos
select id departamento_id,
       nombre departamento_nombre
from departamentos;

-- Zonas
select id zona_id,
       nombre zona_nombre
from zonas;

-- Municipios
select distinct
    m.id municipio_id,
    m.nombre municipio_nombre,
    departamento_id,
    d.nombre departamento_nombre,
    zona_id,
    z.nombre zona_nombre
from municipios m
    join departamentos d on m.departamento_id = d.id
    join zonas z on m.zona_id = z.id
order by municipio_nombre;

-- Estaciones
select
    e.id estacion_id,
    e.nombre estacion_nombre,
    e.municipio_id,
    m.nombre municipio_nombre,
    e.latitud,
    e.longitud
from estaciones e join municipios m on e.municipio_id = m.id
order by e.nombre;

-- Observaciones
select
    o.id observacion_id,
    o.estacion_id,
    e.nombre estacion_nombre,
    o.valor observacion_valor,
    o.fecha observacion_fecha
from observaciones o
    join estaciones e on o.estacion_id = e.id;


-- =====================================================
-- AUTOMATIZACIÒN DE REFRESCO DE VISTAS MATERIALIZADAS
-- =====================================================

create extension if not exists pg_cron;

-- mv_resumen_diario
SELECT cron.schedule(
    'refresh_mv_resumen_diario',
    '0 2 * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_diario'
);

-- mv_resumen_mensual
SELECT cron.schedule(
    'refresh_mv_resumen_mensual',
    '30 2 * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_mensual'
);

-- mv_stats_iqr
SELECT cron.schedule(
    'refresh_mv_stats_iqr',
    '45 2 * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_stats_iqr'
);

--  mv_intervalos
SELECT cron.schedule(
    'refresh_mv_intervalos',
    '0 3 * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_intervalos'
);

-- mv_gaps_por_estacion
SELECT cron.schedule(
    'refresh_mv_gaps_por_estacion',
    '30 3 * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_gaps_por_estacion'
);

-- Verificar jobs registrados
SELECT
    jobid,
    jobname,
    schedule,
    command,
    active
FROM cron.job
ORDER BY jobid;

-- ========================================================
-- Asignación de privilegios para el usuario tempant_qry
-- En caso de requerirse.
-- ========================================================

grant select on mv_inventario_geografico to tempant_qry;
grant select on mv_resumen_diario to tempant_qry;
grant select on mv_resumen_mensual to tempant_qry;
grant select on v_gaps_resumen to tempant_qry;
grant select on v_intervalos_por_estacion to tempant_qry;
grant select on mv_intervalos to tempant_qry;
grant select on v_duplicados_exactos to tempant_qry;
grant select on v_cuasi_duplicados to tempant_qry;
grant select on v_stats_temperatura_por_estacion to tempant_qry;
grant select on v_outliers_fisicos to tempant_qry;
grant select on v_outliers_iqr to tempant_qry;
grant select on v_outliers_zscore to tempant_qry;


-- ===========================================
-- ZONA DE PELIGRO - BORRADO DE OBJETOS
-- ===========================================

-- Borrado de vistas y vistas materializadas
drop view v_gaps_resumen;
drop view v_duplicados_exactos;
drop view v_ubicacion_estacion;
drop view v_info_estaciones;
drop view v_stats_temperatura_por_estacion;
drop view v_intervalos_por_estacion;
drop view v_info_observacion;
drop view v_outliers_fisicos;
drop view v_info_departamentos;
drop view v_outliers_zscore;
drop view v_cuasi_duplicados;
drop view v_outliers_iqr;
drop view v_info_zonas;

drop materialized view mv_gaps_por_estacion;
drop materialized view mv_intervalos;
drop materialized view mv_inventario_geografico;
drop materialized view mv_resumen_diario;
drop materialized view mv_resumen_mensual;
drop materialized view mv_stats_iqr;

-- Borrado de tablas
drop table observaciones;
drop table estaciones;
drop table sensores;
drop table municipios;
drop table zonas;
drop table departamentos;
drop table datos_temporales;

drop sequence departamentos_id_seq;
drop sequence municipios_id_seq;
drop sequence observaciones_id_seq;
drop sequence zonas_id_seq;

