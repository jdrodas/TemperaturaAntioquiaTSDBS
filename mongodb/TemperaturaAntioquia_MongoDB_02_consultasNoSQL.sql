-- Scripts de clase - Mayo de 2026
-- Juan Dario Rodas - jdrodas@hotmail.com

-- Proyecto: Analisis de Temperatura en Antioquia para el año 2024 y 2026
-- Motor de Base de datos: MongoDB 8.x
-- Version: NoSQL Orientada al documento
-- *******************************************************
-- Consultas SQL con enfoque en la perspectiva temporal
-- *******************************************************

-- ********************************************************
-- básicas:
-- ********************************************************


/*
¿Cuál fue la temperatura promedio, máxima y mínima registrada 
en cada estación durante el mes de julio de 2025?
*/

db.observaciones.aggregate([
  {
    // 1. Filtrar los documentos por el rango de fechas (Mes de Julio 2025)
    $match: {
      observacion_fecha: {
        $gte: ISODate("2025-07-01T00:00:00Z"),
        $lt: ISODate("2025-08-01T00:00:00Z")
      }
    }
  },
  {
    // 2. Agrupar por estación y calcular las métricas requeridas
    $group: {
      _id: {
        estacion_id: "$estacion_id",
        estacion_nombre: "$estacion_nombre"
      },
      temperatura_promedio: { $avg: "$observacion_valor" },
      temperatura_maxima: { $max: "$observacion_valor" },
      temperatura_minima: { $min: "$observacion_valor" }
    }
  },
  {
    // 3. Proyectar la salida para que sea limpia y fácil de leer
    $project: {
      _id: 0,
      estacion_id: "$_id.estacion_id",
      estacion_nombre: "$_id.estacion_nombre",
      temperatura_promedio: 1,
      temperatura_maxima: 1,
      temperatura_minima: 1
    }
  }
]);


-- ********************************************************
-- Intermedia:
-- ********************************************************
/*
Para cada municipio, ¿cuál fue el día del año 2025 que registró 
la mayor variación de temperatura (la diferencia absoluta entre 
la temperatura máxima y la mínima del mismo día)?
*/

db.observaciones.aggregate([
  {
    // 1. Filtrar observaciones únicamente del año 2025
    $match: {
      observacion_fecha: {
        $gte: ISODate("2025-01-01T00:00:00Z"),
        $lt: ISODate("2026-01-01T00:00:00Z")
      }
    }
  },
  {
    // 2. Agrupar por municipio y por DÍA (restando horas/minutos de la fecha)
    $group: {
      _id: {
        municipio_id: "$municipio_id",
        municipio_nombre: "$municipio_nombre",
        // Extraemos la fecha en formato YYYY-MM-DD para colapsar el tiempo
        dia: { $dateToString: { format: "%Y-%m-%d", date: "$observacion_fecha" } }
      },
      temp_max: { $max: "$observacion_valor" },
      temp_min: { $min: "$observacion_valor" }
    }
  },
  {
    // 3. Calcular la variación térmica absoluta de ese día
    $project: {
      municipio_id: "$_id.municipio_id",
      municipio_nombre: "$_id.municipio_nombre",
      dia: "$_id.dia",
      variacion_termica: { $subtract: ["$temp_max", "$temp_min"] }
    }
  },
  {
    // 4. Ordenar los resultados por variación descendente
    // (Paso clave para que el día con mayor variación quede arriba por cada municipio)
    $sort: {
      municipio_id: 1,
      variacion_termica: -1
    }
  },
  {
    // 5. Volver a agrupar, esta vez SOLO por municipio, y tomar el primer documento ($first)
    // Como ya vienen ordenados de mayor a menor variación, el primero es el día máximo.
    $group: {
      _id: "$municipio_id",
      municipio_nombre: { $first: "$municipio_nombre" },
      dia_max_variacion: { $first: "$dia" },
      variacion_maxima: { $first: "$variacion_termica" }
    }
  },
  {
    // 6. Limpieza final de la estructura de salida
    $project: {
      _id: 0,
      municipio_id: "$_id",
      municipio_nombre: 1,
      dia_max_variacion: 1,
      variacion_maxima: 1
    }
  }
]);

-- ********************************************************
-- Avanzada:
-- ********************************************************

/*
Detectar posibles anomalías en los sensores: Para cada estación, 
muestra todas las observaciones individuales donde la 
temperatura registrada sea al menos 5 grados superior al 
promedio de las lecturas de esa misma estación durante 
las 4 horas inmediatamente anteriores
*/

db.observaciones.aggregate([
  {
    // 1. Crear la ventana móvil utilizando la sintaxis numérica correcta
    $setWindowFields: {
      partitionBy: "$estacion_id",
      sortBy: { observacion_fecha: 1 },
      output: {
        promedio_ultimas_4h: {
          $avg: "$observacion_valor",
          window: {
            // Definimos el rango numérico: desde 4 unidades atrás hasta la posición actual
            range: [-4, "current"],
            // Aquí especificamos que cada unidad numérica equivale a 1 hora
            unit: "hour"
          }
        }
      }
    }
  },
  {
    // 2. Calcular la diferencia entre la temperatura actual y el promedio
    $project: {
      _id: 0,
      estacion_id: 1,
      estacion_nombre: 1,
      observacion_fecha: 1,
      temperatura_actual: "$observacion_valor",
      promedio_historico_4h: "$promedio_ultimas_4h",
      diferencia_termica: { $subtract: ["$observacion_valor", "$promedio_ultimas_4h"] }
    }
  },
  {
    // 3. Filtrar solo las anomalías (Diferencia >= 5 grados)
    $match: {
      diferencia_termica: { $gte: 5 }
    }
  },
  {
    // 4. Ordenar por fecha reciente
    $sort: {
      observacion_fecha: -1
    }
  }
]);