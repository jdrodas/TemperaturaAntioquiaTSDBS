-- Scripts de clase - Mayo de 2026
-- Juan Dario Rodas - jdrodas@hotmail.com

-- Proyecto: Analisis de Temperatura en Antioquia para el año 2024 y 2026
-- Motor de Base de datos: MongoDB 8.x
-- Version: NoSQL Orientada al documento

-- ***********************************
-- Abastecimiento de imagen en Docker
-- ***********************************
 
-- Descargar la imagen
docker pull mongodb/mongodb-community-server

-- Crear el contenedor
docker run --name mongodb_tempAnt -e “MONGO_INITDB_ROOT_USERNAME=mongoadmin” -e MONGO_INITDB_ROOT_PASSWORD=unaClav3 -p 27017:27017 -d mongodb/mongodb-community-server:latest

-- ****************************************
-- Creación de base de datos y usuarios
-- ****************************************

-- Para conectarse al contenedor
mongodb://mongoadmin:unaClav3@localhost:27017/

-- Con usuario mongoadmin:

-- Para saber que versión de Mongo se está usando
db.version()

-- crear la base de datos
use tempantioquia_db;

-- Crear usuario para gestionar el modelo

db.createUser({
  user: "tempantioquia_app",
  pwd: "unaClav3",  
  roles: [
    { role: "readWrite", db: "tempantioquia_db" },
    { role: "dbAdmin", db: "tempantioquia_db" }
  ],
    mechanisms: ["SCRAM-SHA-256"]
  }
);

-- Con el usuario tempantioquia_app

-- ****************************************
--   Creación de Colecciones
-- ****************************************

-- Básico... solo la colección, luego activamos validaciones

db.createCollection("departamentos");
db.createCollection("zonas");
db.createCollection("municipios");
db.createCollection("sensores");
db.createCollection("estaciones");
db.createCollection("observaciones");

-- ************************************************************
--   Cargar archivos JSON exportados del modelo relacional
-- ************************************************************

-- departamentos.json
-- zonas.json
-- municipios.json
-- sensores.json
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
  let departamento = db.departamentos.findOne({"id":municipio.departamento_id});

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
  let zona = db.zonas.findOne({"id":municipio.zona_id});

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
  let municipio = db.municipios.findOne({"id":estacion.municipio_id});

  if (municipio){
    db.estaciones.updateOne(
      {_id:estacion._id},
      {$set: {"municipio_id": municipio._id}}
    );
  }
}
);

-- Actualización del ObjectId del sensor para las observaciones
-- Usar UpdateOne con colecciones grandes es eeeeeeeteeeeeernooooooooooo.....
-- NO USAR ESTE a menos que tenga mucho tiempo para mirar un cursor parpadear! ;-)

-- db.observaciones.find().forEach(function(observacion){
--     let sensor = db.sensores.findOne({"id":observacion.sensor_id});
-- 
--     if(sensor){
--         db.observaciones.updateOne(
--             {_id:observacion._id},
--             {$set: {"sensor_id":sensor._id}}
--         );
--     }
-- });

-- Usar mejor UpdateMany
db.sensores.find().forEach(function(sensor){
    //Actualizar todas las mediciones asociadas a este sensor en una sola operación
    db.observaciones.updateMany(
        {"sensor_id":sensor.id},        // Filtro: Todas las mediciones con este código de sensor
        {$set: {"sensor_id": sensor._id }}      // Actualización: Establecer el objectId del sensor
    );
}    
);

-- Actualización del ObjectId de la estación para las observaciones
-- Usar mejor UpdateMany
db.estaciones.find().forEach(function(estacion){
    //Actualizar todas las mediciones asociadas a esta estación en una sola operación
    db.observaciones.updateMany(
        {"estacion_id":estacion.id},        // Filtro: Todas las mediciones con este código de estación
        {$set: {"estacion_id": estacion._id }}      // Actualización: Establecer el objectId de la estación
    );
}    
);

-- Actualización del campo fecha para pasar el tipo de dato de string a fecha
db.observaciones.updateMany(
  {}, 
  [{ $set: { fecha: { $toDate: "$fecha" } } }]
);

-- Retirar los campos temporales que ya no son necesarios

-- En Observaciones, quitar los campos de código de sensor y código de estación
db.observaciones.updateMany({}, { $unset: { id: "" } });

-- En sensores, quitar el campo codigo
db.sensores.updateMany({}, { $unset: { id: "" } });

-- En estaciones, quitar el campo codigo de municipio
db.estaciones.updateMany({}, { $unset: { id: "" } });

-- En municipios, quitar los campos de código de departamentos y zonas
db.municipios.updateMany({}, { $unset: { id: "" } });

-- En zonas, quitar el campo codigo
db.zonas.updateMany({}, { $unset: { id: "" } });

-- En departamentos, quitar el campo codigo
db.departamentos.updateMany({}, { $unset: { id: "" } });

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
                "nombre"
            ],
            properties: {
                _id: {
                    bsonType: 'objectId'
                },
                nombre: {
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
                "nombre"
            ],
            properties: {
                _id: {
                    bsonType: 'objectId'
                },
                nombre: {
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
                "nombre",
                "zona_id",
                "zona_nombre",
                "departamento_id",
                "departamento_nombre"
            ],
            properties: {
                _id: {
                    bsonType: 'objectId'
                },
                nombre: {
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

-- Para la colección sensores
db.runCommand({
  collMod: "sensores",
        validator: {
            $jsonSchema: {
                bsonType: 'object',
                title: 'Los sensores donde que se utilizarán para las observaciones',
                required: [
                    "_id",
                    "nombre"
                ],
                properties: {
                    _id: {
                        bsonType: 'objectId'
                    },
                    nombre: {
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

-- Para la colección estaciones
db.runCommand({
  collMod: "estaciones",
        validator: {
            $jsonSchema: {
                bsonType: 'object',
                title: 'Las estaciones donde que se realizarán las observaciones',
                required: [
                    "_id",
                    "nombre",
                    "latitud",
                    "longitud",
                    "municipio_id",
                    "municipio_nombre"
                ],
                properties: {
                    _id: {
                        bsonType: 'objectId'
                    },
                    nombre: {
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
                "valor",
                "unidad_medida",                
                "fecha",
                "estacion_id",                
                "estacion_nombre",
                "sensor_id",                
                "sensor_nombre",
            ],
            properties: {
                _id: {
                    bsonType: 'objectId'
                },
                valor: {
                    bsonType: "number",
                    minimum:-100,
                    maximum: 200,
                    description: "'valor' Debe ser un numero real entre -50 y 150"
                },
                unidad_medida: {
                    bsonType: "string",
                    description: "'unidad_medida' Debe ser una cadena de caracteres y no puede ser nulo",
                    minLength: 2
                },  
                fecha: {
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
                }, 
                sensor_id: {
                    bsonType: ['objectId','string'],
                    description: '\'sensor_id\' Es el ObjectId del sensor'
                }, 
                sensor_nombre: {
                    bsonType: 'string',
                    description: "'sensor_nombre' Debe ser una cadena de caracteres y no puede ser nulo",
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
    timeField: "fecha",
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
      fecha: 1,
      valor: 1,
      unidad_medida: 1,
      metadata: {
        estacion_id: "$estacion_id",
        estacion_nombre: "$estacion_nombre", 
        sensor_id: "$sensor_id",
        sensor_nombre: "$sensor_nombre"
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


-- ****************************************
--   Zona de pruebas
-- ****************************************

