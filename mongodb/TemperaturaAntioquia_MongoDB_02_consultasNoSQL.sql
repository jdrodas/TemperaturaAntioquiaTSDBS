-- Scripts de clase - Mayo de 2026
-- Juan Dario Rodas - jdrodas@hotmail.com

-- Proyecto: Analisis de Temperatura en Antioquia para el año 2024 y 2026
-- Motor de Base de datos: MongoDB 8.x
-- Version: NoSQL Orientada al documento
-- *******************************************************
-- Consultas SQL con enfoque en la perspectiva temporal
-- *******************************************************

-- ********************************************************
-- Superbásicas:
-- ********************************************************

-- ------------------------------------------------------------------------------------------
-- ¿Hay datos duplicados por estación, sensor y fecha con valores distintos?
-- R/. Esta consulta no debe arrojar resultados
-- ------------------------------------------------------------------------------------------

db.observaciones.aggregate([
  {
    $group: {
      _id: {
        estacion_id: "$estacion_id",
        fecha: "$observacion_fecha"
      },
      valores_distintos: { $addToSet: "$valor" },
      total_duplicados: { $sum: 1 }
    }
  },
  {
    $match: {
      total_duplicados: { $gt: 1 }
    }
  },
  {
    $project: {
      _id: 0,
      estacion_id: "$_id.estacion_id",
      fecha: "$_id.observacion_fecha",
      valores_distintos: 1,
      total_duplicados: 1,
      rango_valores: {
        $subtract: [
          { $max: "$valores_distintos" },
          { $min: "$valores_distintos" }
        ]
      }
    }
  },
  {
    $sort: { rango_valores: -1 }
  }
]);


-- ------------------------------------------------------------------------------------------
-- ¿Hay días sin observaciones por estación?
-- R/. Esta consulta no debe arrojar resultados
-- ------------------------------------------------------------------------------------------
    db.observaciones.aggregate([
    {
        $group: {
        _id: {
            año: { $year: "$observacion_fecha" },
            mes: { $month: "$observacion_fecha" },
            dia: { $dayOfMonth: "$observacion_fecha" }
        }
        }
    },
    {
        $group: {
        _id: {
            año: "$_id.año",
            mes: "$_id.mes"
        },
        dias_con_datos: { $sum: 1 }
        }
    },
    {
        $addFields: {
            dias_esperados: {
                $cond: {
                    if: { $eq: ["$_id.mes", 2] }, // Febrero - 28 días
                    then: 28,
                    else: {
                        $cond: {
                            if: { $in: ["$_id.mes", [4, 6, 9, 11]] }, // Meses con 30 días
                            then: 30,
                            else: 31 // Resto de meses
                        }
                    }
                }            
            }
        }
    },
    {
        $project: {
        _id: 0,
        año: "$_id.año",
        mes: "$_id.mes",
        dias_con_datos: 1,
        dias_esperados: 1,
        dias_sin_datos: { $subtract: ["$dias_esperados", "$dias_con_datos"] },
        porcentaje_cobertura: {
            $multiply: [
            { $divide: ["$dias_con_datos", "$dias_esperados"] },
            100
            ]
        }
        }
    },
    {
        $sort: { año: 1,
                  mes: 1 }
    }
    ]);

-- ------------------------------------------------------------------------------------------
-- ¿Distribución de observaciones por hora a nivel global?
-- R/. Esta consulta debería arrojar que todas las horas entre 0 - 23 tienen
--      la misma cantidad de mediciones y su porcentaje es similar
-- ------------------------------------------------------------------------------------------

db.observaciones.aggregate([
  {
    $project: {
      hora: { $hour: "$observacion_fecha" }
    }
  },
  {
    $group: {
      _id: "$hora",
      total_observaciones: { $sum: 1 }
    }
  },
  {
    $group: {
      _id: null,
      horas: {
        $push: {
          hora: "$_id",
          observaciones: "$total_observaciones"
        }
      },
      total_global: { $sum: "$total_observaciones" }
    }
  },
  {
    $unwind: "$horas"
  },
  {
    $project: {
      _id: 0,
      hora: "$horas.hora",
      observaciones: "$horas.observaciones",
      porcentaje_cobertura: {
        $multiply: [
          { $divide: ["$horas.observaciones", "$total_global"] },
          100
        ]
      }
    }
  },
  {
    $sort: { hora: 1 }
  }
]);



-- ------------------------------------------------------------------------------------------
-- Identificar lapsos irregulares entre observaciones por estación
-- R/. Esta consulta debería arrojar que todas las mediciones por estaciones están 
--      igualmente espaciadas
-- ------------------------------------------------------------------------------------------
db.observaciones.aggregate([
  {
    $sort: { estacion_id: 1, fecha: 1 }
  },
  {
    $group: {
      _id: "$estacion_id",
      estacion_nombre: { $first: "$estacion_nombre" },
      observaciones: { $push: "$observacion_fecha" },
      total_observaciones: { $sum: 1 }
    }
  },
  {
    $project: {
      _id: 0,
      estacion_id: "$_id",
      estacion_nombre: 1,
      total_observaciones: 1,
      diferencias_minutos: {
        $map: {
          input: { $range: [1, { $size: "$observaciones" }] },
          as: "idx",
          in: {
            $divide: [
              { $subtract: [
                { $arrayElemAt: ["$observaciones", "$$idx"] },
                { $arrayElemAt: ["$observaciones", { $subtract: ["$$idx", 1] }] }
              ] },
              60000 // Convierte milisegundos a minutos
            ]
          }
        }
      }
    }
  },
  {
    $project: {
      estacion_id: 1,
      estacion_nombre: 1,
      total_observaciones: 1,
      lapso_minimo: { $round: [{ $min: "$diferencias_minutos" }, 3] },
      lapso_promedio: { $round: [{ $avg: "$diferencias_minutos" }, 3] },
      lapso_maximo: { $round: [{ $max: "$diferencias_minutos" }, 3] },
      desviacion_estandar: { $round: [{ $stdDevPop: "$diferencias_minutos" }, 3] }
    }
  },
  {
    $sort: { estacion_nombre: 1 }
  }
]);



-- ------------------------------------------------------------------------------------------
-- Temperatura promedio por estación en el mes de mayo
-- ------------------------------------------------------------------------------------------
-- Versión en colección time series
db.mediciones.aggregate([
  {
    $match: {
      observacion_fecha: {
        $gte: ISODate("2025-05-01T00:00:00.000Z"),
        $lt: ISODate("2025-06-01T00:00:00.000Z")
      }
    }
  },
  {
    $group: {
      _id: "$metadata.estacion_nombre",
      temperatura_promedio: { $avg: "$observacion_valor" },
      total_mediciones: { $sum: 1 },
      estacion_id: { $first: "$metadata.estacion_id" }
    }
  },
  {
    $project: {
      _id: 0,
      estacion_nombre: "$_id",
      estacion_id: 1,
      temperatura_promedio: { $round: ["$temperatura_promedio", 2] },
      total_mediciones: 1
    }
  },
  {
    $sort: { temperatura_promedio: -1 }
  }
]);

-- Versión en colección de propósito general
db.observaciones.aggregate([
  {
    $match: {
      fecha: {
        $gte: ISODate("2025-05-01T00:00:00.000Z"),
        $lt: ISODate("2025-06-01T00:00:00.000Z")
      }
    }
  },
  {
    $group: {
      _id: "$estacion_nombre",
      temperatura_promedio: { $avg: "$valor" },
      total_mediciones: { $sum: 1 },
      estacion_id: { $first: "$estacion_id" }
    }
  },
  {
    $project: {
      _id: 0,
      estacion_nombre: "$_id",
      estacion_id: 1,
      temperatura_promedio: { $round: ["$temperatura_promedio", 2] },
      total_mediciones: 1
    }
  },
  {
    $sort: { temperatura_promedio: -1 }
  }
]);