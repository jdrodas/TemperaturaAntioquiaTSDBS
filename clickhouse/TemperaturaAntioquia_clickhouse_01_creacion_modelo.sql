-- Scripts de clase - Mayo de 2026
-- Juan Dario Rodas - jdrodas@hotmail.com

-- Proyecto: Analisis de Temperatura en Antioquia para el año 2024 y 2026
-- Motor de Base de datos: ClickHouse 26.5.x
-- Version: Columnar

-- ***********************************
-- Abastecimiento de imagen en Docker
-- ***********************************

-- Descargar la imagen
docker pull clickhouse:latest

-- Crear el contenedor
docker run --name tempant-ch -e CLICKHOUSE_USER=default -e CLICKHOUSE_PASSWORD=unaClav3 -e CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1 -e CLICKHOUSE_DB=tempant_db -d -p 8123:8123 -p 9000:9000 clickhouse:latest
  
-- desde sh, validar funcionamiento del contenedor
docker exec -it tempant-ch clickhouse-client --user default --password 'unaClav3' --query "SELECT version()"

-- Si funciona, debe dar el número de la versión del motor, 26.5.1.882 o superior


-- ****************************************
-- Creación de base de datos y usuarios
-- ****************************************

-- Con el usuario default:

-- Creación de la base de datos, si no creó al momento de crear el contenedor
create database tempant_db comment 'Base de datos de mediciones de temperatura ambiente - Antioquia';

-- creación del usuario
create user tempant_usr identified with sha256_password by 'unaClav3' default database tempant_db;
