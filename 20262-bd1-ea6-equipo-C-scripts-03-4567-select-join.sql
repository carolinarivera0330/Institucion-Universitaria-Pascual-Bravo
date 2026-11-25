-- ---------------------------------------------------------------------------------
-- Scripts - Enunciados 3, 4, 5, 6 y 7 DML para consultas Sin Join, 1 Join, 2 Join, 3 Join y 4 Join
-- ---------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------
-- 0.- PREPARACIÓN (ejecutar UNA sola vez antes de las consultas)
-- Su poblamiento no tiene columnas de estado. Se agregan y se rellenan.
-- ---------------------------------------------------------------------------------
ALTER TABLE producto
    ADD COLUMN IF NOT EXISTS estado_disponibilidad VARCHAR(20) DEFAULT 'Disponible';

UPDATE producto
SET estado_disponibilidad = CASE
        WHEN random() < 0.70 THEN 'Disponible'
        WHEN random() < 0.50 THEN 'Agotado'
        ELSE 'Vendido'
    END;

ALTER TABLE transaccion
    ADD COLUMN IF NOT EXISTS estado_transaccion VARCHAR(20) DEFAULT 'Completado';

UPDATE transaccion
SET estado_transaccion = CASE
        WHEN random() < 0.60 THEN 'Completado'
        WHEN random() < 0.50 THEN 'Pendiente'
        ELSE 'Cancelado'
    END;


-- ---------------------------------------------------------------------------------
-- 3.- Enunciado para Consulta sin JOIN
-- Análisis de Precios y Disponibilidad en Oferta de Productos
-- ---------------------------------------------------------------------------------
SELECT
    id_producto                              AS codigo_producto,
    nombre_producto                          AS titulo_descriptivo,
    ROUND(precio_producto * 1.05, 2)         AS precio_venta_con_recargo_5_pct,
    estado_disponibilidad                    AS estado
FROM producto
WHERE precio_producto BETWEEN 50000 AND 500000
  AND estado_disponibilidad = 'Disponible'
ORDER BY precio_producto DESC
LIMIT 20;


-- ---------------------------------------------------------------------------------
-- 4.- Enunciado para consulta con 1 JOIN.
-- Censo Institucional de Usuarios por Categoría
-- ---------------------------------------------------------------------------------
SELECT
    tu.nombre_tipo_usuario   AS categoria_institucional,
    COUNT(u.id_usuario)      AS total_usuarios
FROM usuario u
JOIN tipo_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario
GROUP BY tu.nombre_tipo_usuario
ORDER BY total_usuarios DESC;


-- ---------------------------------------------------------------------------------
-- 5.- Enunciado para consulta con 2 JOINs
-- Trazabilidad de Eventos Académicos y sus Organizadores
-- ---------------------------------------------------------------------------------
-- NOTA: el poblamiento genera eventos alrededor de la fecha actual (2026).
-- Para que esta consulta devuelva filas con 2024/2025, ajuste la fecha en el
-- generador de eventos (ver el UPDATE de abajo) o el filtro.
SELECT
    e.nombre_evento             AS titulo_evento,
    te.nombre_tipo_evento       AS tipo_evento,
    e.fecha_evento              AS fecha_realizacion,
    u.nombre_usuario            AS organizador,
    u.correo_electronico        AS correo_institucional
FROM evento e
JOIN tipo_evento te ON te.id_tipo_evento = e.id_tipo_evento
JOIN usuario u      ON u.id_usuario      = e.id_usuario_organizador
WHERE EXTRACT(YEAR FROM e.fecha_evento) IN (2024, 2025)
ORDER BY e.fecha_evento;

-- (Opcional) Si el resultado sale vacío, repartir las fechas entre 2024 y 2026:
-- UPDATE evento
-- SET fecha_evento = TIMESTAMP '2024-01-01' + (random() * interval '1000 days');


-- ---------------------------------------------------------------------------------
-- 6.- Enunciado para consulta SELECT con 3 JOINs
-- Consumo de Servicios Académicos por Estudiantes Activos
-- ---------------------------------------------------------------------------------
-- NOTA: en este modelo no existe servicio_solicitud. La solicitud de un servicio
-- es una fila de detalle_transaccion con id_servicio, ligada a transaccion
-- (comprador, fecha y estado). Por eso se requieren 4 JOINs en lugar de 3.
SELECT
    u.nombre_usuario          AS estudiante_solicitante,
    s.descripcion_servicio    AS servicio_solicitado,
    ts.nombre_tipo_servicio   AS categoria_servicio,
    t.fecha_transaccion       AS fecha_solicitud
FROM detalle_transaccion d
JOIN transaccion t    ON t.id_transaccion   = d.id_transaccion
JOIN servicio s       ON s.id_servicio      = d.id_servicio
JOIN tipo_servicio ts ON ts.id_tipo_servicio = s.id_tipo_servicio
JOIN usuario u        ON u.id_usuario       = t.id_usuario_comprador
WHERE u.id_tipo_usuario = 1
  AND t.estado_transaccion = 'Completado'
ORDER BY t.fecha_transaccion DESC;


-- ---------------------------------------------------------------------------------
-- 7.- Enunciado para consulta con 4 JOINs
-- Reporte Transaccional Consolidado de Venta de Productos
-- ---------------------------------------------------------------------------------
-- NOTA: el comprador vive en transaccion, no en el detalle; por eso este modelo
-- necesita 5 JOINs (6 tablas) para cubrir lo que pide el enunciado.
SELECT
    p.nombre_producto               AS titulo_producto,
    tp.nombre_tipo_producto         AS categoria_producto,
    d.precio_unitario               AS precio_pagado,
    u.nombre_usuario                AS comprador,
    tu.nombre_tipo_usuario          AS tipo_usuario_comprador
FROM detalle_transaccion d
JOIN transaccion t     ON t.id_transaccion    = d.id_transaccion
JOIN producto p        ON p.id_producto       = d.id_producto
JOIN tipo_producto tp  ON tp.id_tipo_producto = p.id_tipo_producto
JOIN usuario u         ON u.id_usuario        = t.id_usuario_comprador
JOIN tipo_usuario tu   ON tu.id_tipo_usuario  = u.id_tipo_usuario
WHERE tu.nombre_tipo_usuario IN ('Egresado', 'Estudiante')
  AND d.precio_unitario > 100000
ORDER BY d.precio_unitario DESC;




