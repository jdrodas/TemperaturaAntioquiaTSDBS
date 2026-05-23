-- Scripts de clase - Mayo de 2026
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
Rango fechas: Enero 1 de 2024, 12:00 am a Abril 30 2026, 11:58 pm.
Total registros iniciales antes de control de calidad: -- Pendiente determinar

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

comment on table estaciones is 'Estaciones de Medición de Temperatura';
comment on column estaciones.id is 'Id de la estación';
comment on column estaciones.nombre is 'nombre de la estación';
comment on column estaciones.municipio_id is 'Id del municipio donde está la estación';
comment on column estaciones.latitud is 'Componente latitud de la coordenada geográfica de la estación';
comment on column estaciones.longitud is 'Componente longitud de la coordenada geográfica de la estación';

-- Tabla: Sensores
create table sensores
(
    id              text not null constraint sensores_pk primary key,
    nombre          text not null constraint nombre_sensor_uk unique
);

comment on table sensores is 'Sensores de medición de temperatura';
comment on column sensores.id is 'Id del sensor';
comment on column sensores.nombre is 'Nombre del sensor';


-- Tabla: Observaciones
create table observaciones
(
    id              integer generated always as identity constraint observaciones_pk primary key,
    estacion_id     text not null constraint observaciones_estaciones_fk references estaciones,
    sensor_id       text not null constraint observaciones_sensores_fk references sensores,
    valor           float not null,
    unidad_medida   text not null,
    fecha           timestamp without time zone not null 
);

comment on table observaciones is 'Observaciones de temperatura realizadas por las estaciones';
comment on column observaciones.id is 'Id de la observación';
comment on column observaciones.estacion_id is 'Id de la estación que hizo la observación';
comment on column observaciones.valor is 'valor de temperatura obtenido en la observación';
comment on column observaciones.unidad_medida is 'unidad de medida de temperatura de la observación';
comment on column observaciones.fecha is 'fecha en la que se realizó la la observación de temperatura';

-- ===========================================
-- Cargue de datos desde la tabla provisional 
-- ===========================================

-- Departamentos
insert into departamentos (nombre)
select distinct departamento
from datos_temporales;

-- Devolver el Id generado a la tabla provisional
alter table datos_temporales add column departamento_id int default 1;

-- Zonas 
insert into zonas (nombre)
select distinct ZonaHidrografica from datos_temporales;

-- Devolver el Id generado a la tabla provisional
alter table datos_temporales add column zona_id int;

update datos_temporales
set zona_id =
    (select distinct id from zonas where lower(nombre) = lower(ZonaHidrografica))
where zona_id is null;

-- Municipios
insert into municipios (nombre, departamento_id, zona_id)
select distinct municipio, departamento_id, zona_id
from datos_temporales
order by zona_id, municipio;

-- Devolver el Id generado a la tabla provisional
alter table datos_temporales add column municipio_id int;

-- Devolver el Id generado a la tabla provisional
update datos_temporales dp
set municipio_id =
    (select distinct id
     from municipios m
     where lower(nombre) = lower(dp.municipio)
     and m.zona_id = dp.zona_id
     and m.departamento_id = dp.departamento_id)
where municipio_id is null;

-- Estaciones
insert into estaciones (id, nombre, municipio_id,latitud,longitud)
select distinct
    codigoestacion,
    nombreestacion,
    municipio_id,
    replace(latitud,',','.')::double precision latitud,
    replace(longitud,',','.')::double precision longitud
from datos_temporales;

-- Sensores
insert into sensores (id, nombre)
select distinct 
    codigoSensor,
    descripcionSensor
from datos_temporales;


-- Observaciones:
insert into observaciones (estacion_id, sensor_id, valor, unidad_medida, fecha)
select distinct
    codigoestacion,
    codigosensor,
    replace(valorobservado,',','.')::double precision valor_medicion,
    UnidadMedida,
    to_timestamp(fechaobservacion::text, 'YYYY Mon DD HH12:MI:SS AM') fecha_medicion
from datos_temporales
order by to_timestamp(fechaobservacion::text, 'YYYY Mon DD HH12:MI:SS AM'), codigoestacion;


-- ===========================================
-- Creación de Vistas
-- ===========================================

-- vista: v_info_observacion
create or replace view v_info_observacion as
(
    select distinct
        o.id observacion_id,
        o.fecha,
        o.valor,
        o.estacion_id,
        e.nombre estacion_nombre,
        o.sensor_id,
        s.nombre sensor_nombre,
        e.municipio_id,
        m.nombre municipio_nombre,
        m.zona_id,
        zh.nombre zona_nombre,
        m.departamento_id,
        d.nombre departamento_nombre
    from observaciones o
        inner join estaciones e on o.estacion_id = e.id
        inner join municipios m on e.municipio_id = m.id
        inner join zonas zh on m.zona_id = zh.id
        inner join departamentos d on m.departamento_id = d.id
        inner join sensores s on o.sensor_id = s.id
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
-- Creación de Vistas Materializadas
-- ===========================================

-- Materialized View: mv_estadisticas_outliers
create materialized view mv_estadisticas_outliers as (
WITH estadisticas_por_mes_estacion AS (
    -- Calcula estadísticas por mes y estación
    SELECT
        estacion_id,
        EXTRACT(MONTH FROM fecha) AS mes,
        EXTRACT(YEAR FROM fecha) as año,
        AVG(valor) AS promedio,
        STDDEV(valor) AS desviacion_estandar,
        MIN(valor) AS minimo,
        MAX(valor) AS maximo,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY valor) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY valor) AS q3
    FROM observaciones
    GROUP BY estacion_id, EXTRACT(MONTH FROM fecha), EXTRACT(YEAR FROM fecha)
),
outliers AS (
    -- Identifica valores atípicos usando el método del rango intercuartílico (IQR)
    SELECT
        o.id observacion_id,
        o.estacion_id,
        e.nombre AS estacion_nombre,
        o.sensor_id,
        s.nombre AS sensor_nombre,
        o.fecha,
        o.valor,
        est.promedio,
        est.desviacion_estandar,
        est.q1,
        est.q3,
        est.q3 - est.q1 AS iqr,
        est.q1 - 1.5 * (est.q3 - est.q1) AS limite_inferior,
        est.q3 + 1.5 * (est.q3 - est.q1) AS limite_superior,
        CASE
            WHEN o.valor < est.q1 - 1.5 * (est.q3 - est.q1) THEN 'Outlier bajo'
            WHEN o.valor > est.q3 + 1.5 * (est.q3 - est.q1) THEN 'Outlier alto'
            ELSE 'Normal'
        END AS tipo_outlier
    FROM observaciones o
    JOIN estaciones e ON o.estacion_id = e.id
    join sensores s on o.sensor_id = s.id
    JOIN estadisticas_por_mes_estacion est ON
        o.estacion_id = est.estacion_id AND
        EXTRACT(MONTH FROM o.fecha) = est.mes
)
SELECT
    observacion_id,
    estacion_id,
    estacion_nombre,
    sensor_id,
    sensor_nombre,
    fecha,
    valor,
    tipo_outlier,
    round(limite_inferior::numeric,3) limite_inferior,
    round(promedio::numeric,3) promedio,
    round(limite_superior::numeric,3) limite_superior,
    round(q1::numeric,3) percentil_25,
    round(q3::numeric,3) percentil_75,
    round(desviacion_estandar::numeric,4) desviacion_estandar
FROM outliers
WHERE tipo_outlier IN ('Outlier bajo', 'Outlier alto')
    );

-- ===========================================
-- Validación de rangos de tiempo procesados
-- ===========================================
-- Crudos
select
    min(to_timestamp(fechaobservacion::text, 'YYYY Mon DD HH12:MI:SS AM')) fecha_minima,
    max(to_timestamp(fechaobservacion::text, 'YYYY Mon DD HH12:MI:SS AM')) fecha_minima
from datos_temporales

-- Normalizados
select
    min(fecha) fecha_minima,
    max(fecha) fecha_maxima
from observaciones;



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

-- Sensores
select id sensor_id,
       nombre sensor_nombre
from sensores;

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
    o.sensor_id,
    s.nombre sensor_nombre,
    o.valor observacion_valor,
    o.unidad_medida,
    o.fecha observacion_fecha
from observaciones o
    join estaciones e on o.estacion_id = e.id
    join sensores s on o.sensor_id = s.id;



-- ===========================================
-- ZONA DE PELIGRO - BORRADO DE OBJETOS
-- ===========================================

-- Borrado de vistas
drop materialized view mv_estadisticas_outliers;
drop view v_ubicacion_estacion;
drop view v_ubicacion_observacion;

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