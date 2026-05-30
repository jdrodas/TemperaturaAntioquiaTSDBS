-- Scripts de clase - Mayo de 2026
-- Juan Dario Rodas - jdrodas@hotmail.com

-- Proyecto: Analisis de Temperatura en Antioquia para el año 2024 y 2026
-- Motor de Base de datos: MongoDB 8.3.x
-- Version: NoSQL Orientada al documento

-- ***********************************
-- Abastecimiento de imagen en Docker
-- ***********************************
 
-- Descargar la imagen
docker pull mongodb/mongodb-community-server

-- Crear el contenedor
docker run --name tempAnt-mongodb -e “MONGO_INITDB_ROOT_USERNAME=mongoadmin” -e MONGO_INITDB_ROOT_PASSWORD=unaClav3 -p 27017:27017 -d mongodb/mongodb-community-server:latest

-- ****************************************
-- Creación de base de datos y usuarios
-- ****************************************

-- Para conectarse al contenedor
mongodb://mongoadmin:unaClav3@localhost:27017/

-- Con usuario mongoadmin:

-- Para saber que versión de Mongo se está usando
db.version()

-- crear la base de datos
use tempant_db;

-- Crear usuario para gestionar el modelo

db.createUser({
  user: "tempant_usr",
  pwd: "unaClav3",  
  roles: [
    { role: "readWrite", db: "tempant_db" },
    { role: "dbAdmin", db: "tempant_db" }
  ],
    mechanisms: ["SCRAM-SHA-256"]
  }
);

-- Con el usuario tempant_usr

-- ****************************************
--   Creación de Colecciones
-- ****************************************

-- Básico... solo la colección, luego activamos validaciones

db.createCollection("departamentos");
db.createCollection("zonas");
db.createCollection("municipios");
db.createCollection("estaciones");
db.createCollection("observaciones");

-- ************************************************************
--   Cargar archivos JSON exportados del modelo relacional
-- ************************************************************

-- departamentos.json
-- zonas.json
-- municipios.json
-- estaciones.json
-- observaciones.json

-- *****************************
-- Ajuste del modelo de datos
-- *****************************

/*
Al exportar el modelo de datos desde un esquema relacional, la integridad
referencial debe ajustarse con la utilización de los objectId que son
nativos a MongoDB.
*/

-- Actualización de ObjectId del departamento para los municipios
db.municipios.find().forEach(function(municipio){
  let departamento = db.departamentos.findOne({"departamento_id":municipio.departamento_id});

  if (departamento){
    db.municipios.updateOne(
      {_id:municipio._id},
      {$set: {"departamento_id" : departamento._id}}
    );
  } 
}
);

-- Actualización de ObjectId de la zona para los municipios
db.municipios.find().forEach(function(municipio){
  let zona = db.zonas.findOne({"zona_id":municipio.zona_id});

  if (zona){
    db.municipios.updateOne(
      {_id:municipio._id},
      {$set: {"zona_id" : zona._id}}
    );
  }
}
);

-- Actualización de ObjectId del municipio para las estaciones
db.estaciones.find().forEach(function(estacion){
  let municipio = db.municipios.findOne({"municipio_id":estacion.municipio_id});

  if (municipio){
    db.estaciones.updateOne(
      {_id:estacion._id},
      {$set: {"municipio_id": municipio._id}}
    );
  }
}
);

-- Actualización del ObjectId de la estación para las observaciones
-- Usar mejor UpdateMany
db.estaciones.find().forEach(function(estacion){
    //Actualizar todas las mediciones asociadas a esta estación en una sola operación
    db.observaciones.updateMany(
        {"estacion_id":estacion.estacion_id},        // Filtro: Todas las mediciones con este código de estación
        {$set: {"estacion_id": estacion._id }}      // Actualización: Establecer el objectId de la estación
    );
}    
);

-- Actualización del campo fecha para pasar el tipo de dato de string a fecha
db.observaciones.updateMany(
  {}, 
  [{ $set: { observacion_fecha: { $toDate: "$observacion_fecha" } } }]
);

-- Retirar los campos temporales que ya no son necesarios

-- En Observaciones, quitar los campos de código de sensor y código de estación
db.observaciones.updateMany({}, { $unset: { observacion_id: "" } });

-- En estaciones, quitar el campo codigo de municipio
db.estaciones.updateMany({}, { $unset: { estacion_id: "" } });

-- En municipios, quitar los campos de código de departamentos y zonas
db.municipios.updateMany({}, { $unset: { municipio_id: "" } });

-- En zonas, quitar el campo codigo
db.zonas.updateMany({}, { $unset: { zona_id: "" } });

-- En departamentos, quitar el campo codigo
db.departamentos.updateMany({}, { $unset: { departamento_id: "" } });

-- ************************************************
-- Activación de validadores en las colecciones
-- ************************************************

-- Para la colección departamentos
db.runCommand({
  collMod: "departamentos",
  validator: {
        $jsonSchema: {
            bsonType: 'object',
            title: 'Los departamentos donde estarán ubicados los municipios',
            required: [
                "_id",
                "departamento_nombre"
            ],
            properties: {
                _id: {
                    bsonType: 'objectId'
                },
                departamento_nombre: {
                    bsonType: 'string',
                    description: "'nombre' Debe ser una cadena de caracteres y no puede ser nulo",
                    minLength: 3
                }
            },
            additionalProperties: false
        }
  },
  validationLevel: "strict",
  validationAction: "error"
});

-- Para la colección zonas
db.runCommand({
  collMod: "zonas",
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            title: 'Las zonas donde estarán ubicados los municipios',
            required: [
                "_id",
                "zona_nombre"
            ],
            properties: {
                _id: {
                    bsonType: 'objectId'
                },
                zona_nombre: {
                    bsonType: 'string',
                    description: "'nombre' Debe ser una cadena de caracteres y no puede ser nulo",
                    minLength: 3
                }
            },
            additionalProperties: false            
        }
    },
  validationLevel: "strict",
  validationAction: "error"
});

-- Para la colección municipios
db.runCommand({
  collMod: "municipios",
        validator: {
        $jsonSchema: {
            bsonType: 'object',
            title: 'Los municipios donde estarán ubicados las estaciones',
            required: [
                "_id",
                "municipio_nombre",
                "zona_id",
                "zona_nombre",
                "departamento_id",
                "departamento_nombre"
            ],
            properties: {
                _id: {
                    bsonType: 'objectId'
                },
                municipio_nombre: {
                    bsonType: 'string',
                    description: '\'nombre\' Debe ser una cadena de caracteres y no puede ser nulo',
                    minLength: 3
                },
                zona_id: {
                    bsonType: ['objectId','string'],
                    description: '\'zona_id\' Es el ObjectId de la zona'
                },
                zona_nombre: {
                    bsonType: 'string',
                    description: '\'zona_nombre\' Debe ser una cadena de caracteres y no puede ser nulo',
                    minLength: 3
                },
                departamento_id: {
                    bsonType: ['objectId','string'],
                    description: '\'zona_id\' Es el ObjectId del departamento'
                },            
                departamento_nombre: {
                    bsonType: 'string',
                    description: '\'zona_nombre\' Debe ser una cadena de caracteres y no puede ser nulo',
                    minLength: 3
                },                
            },
            additionalProperties: false  
        }
    },
  validationLevel: "strict",
  validationAction: "error"
});



-- Para la colección estaciones
db.runCommand({
  collMod: "estaciones",
        validator: {
            $jsonSchema: {
                bsonType: 'object',
                title: 'Las estaciones donde que se realizarán las observaciones',
                required: [
                    "_id",
                    "estacion_nombre",
                    "latitud",
                    "longitud",
                    "municipio_id",
                    "municipio_nombre"
                ],
                properties: {
                    _id: {
                        bsonType: 'objectId'
                    },
                    estacion_nombre: {
                        bsonType: 'string',
                        description: "'nombre' Debe ser una cadena de caracteres y no puede ser nulo",
                        minLength: 3
                    },                  
                    latitud: {
                      bsonType: "number",
                      minimum:-90,
                      maximum:90,
                      description: "'latitud' Debe ser un numero real entre -90 y 90"
                    },
                    longitud: {
                      bsonType: "number",
                      minimum:-180,
                      maximum:180,
                      description: "'longitud' Debe ser un numero real entre -180 y 180"
                    },
                    municipio_id: {
                        bsonType: ['objectId','string'],
                        description: '\'zona_id\' Es el ObjectId del municipio'
                    }, 
                    municipio_nombre: {
                        bsonType: 'string',
                        description: "'municipio_nombre' Debe ser una cadena de caracteres y no puede ser nulo",
                        minLength: 3
                    }                      
                },
                additionalProperties: false  
            }
        },
  validationLevel: "strict",
  validationAction: "error"
});

-- Para la colección observaciones
db.runCommand({
  collMod: "observaciones",
  validator: {
        $jsonSchema: {
            bsonType: 'object',
            title: 'Las observaciones realizadas por los sensores ubicados en las estaciones',
            required: [
                "_id",
                "osbservacion_valor",              
                "osbservacion_fecha",
                "estacion_id",                
                "estacion_nombre"
            ],
            properties: {
                _id: {
                    bsonType: 'objectId'
                },
                osbservacion_valor: {
                    bsonType: "number",
                    minimum:-50,
                    maximum: 60,
                    description: "'valor' Debe ser un numero real entre -50 y 60"
                },  
                osbservacion_fecha: {
                    bsonType: "date",
                    description: "'fecha' corresponde a la fecha y hora de la medición"
                },
                estacion_id: {
                    bsonType: ['objectId','string'],
                    description: '\'estacion_id\' Es el ObjectId de la estación'
                }, 
                estacion_nombre: {
                  bsonType: 'string',
                  description: '\'estacion_nombre\' Debe ser una cadena de caracteres y no puede ser nulo',
                  minLength: 3
                } 
            },
            additionalProperties: false  
          }
      },
  validationLevel: "strict",
  validationAction: "error"
});


-- *****************************************************************
--   Creación de la colección habilitada para series de tiempo
-- *****************************************************************

-- Crear la colección mediciones como time series enabled
db.createCollection("mediciones", {
  timeseries: {
    timeField: "observacion_fecha",
    metaField: "metadata",
    granularity: "minutes"
  }
});

-- Si se quiere refrescar totalmente
-- Borrado del contenido de la colección mediciones
db.mediciones.deleteMany({});

-- Insertar datos transformados
db.observaciones.aggregate([
  {
    $project: {
      observacion_fecha: 1,
      observacion_valor: 1,
      metadata: {
        estacion_id: "$estacion_id",
        estacion_nombre: "$estacion_nombre"
      }
    }
  },
  { $out: "mediciones" }
], { allowDiskUse: true });

-- ****************************************
--   Zona de peligro
-- ****************************************

-- Borrado del contenido de la colección mediciones
db.mediciones.deleteMany({});

-- Borrado de colecciones
db.mediciones.drop();
db.observaciones.drop();
db.sensores.drop();
db.estaciones.drop();
db.municipios.drop();
db.departamentos.drop();
db.zonas.drop();


