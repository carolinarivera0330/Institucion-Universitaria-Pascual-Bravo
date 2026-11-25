--
-- Scripts - 8.- Enunciados para Consultas con Funciones de Agregación
-- Equipo C - Base de Datos I (SD1006) - Red Social Pascualina - PostgreSQL
--
-- NOTA: los nombres de tablas y columnas se tomaron del script 01 (poblamiento).
-- Si el DDL del equipo usa otros nombres, ajustar solo los identificadores.

-- ---------------------------------------------------------------------------------------------------------------------------------
-- Script del Enunciado 8.1 — Función COUNT: Volumen Global de Solicitudes de Servicio
-- Calcular la cantidad total de solicitudes de servicios registradas en la plataforma agrupadas por el estado de la transacción (Completado, Pendiente, Cancelado). 
-- ---------------------------------------------------------------------------------------------------------------------------------

-- Versión principal: solicitudes registradas en la plataforma (solicitud_mentoria) agrupadas por su estado.
-- Estados presentes en el poblamiento: PENDIENTE, ACEPTADA, FINALIZADA, RECHAZADA.
SELECT
    estado_solicitud            AS estado,
    COUNT(*)                    AS total_solicitudes
FROM solicitud_mentoria
GROUP BY estado_solicitud
ORDER BY total_solicitudes DESC;

-- Total global (verificación: debe coincidir con la suma de la consulta anterior).
SELECT COUNT(*) AS total_global_solicitudes
FROM solicitud_mentoria;

-- Versión alternativa: si el DDL de "transaccion" tiene una columna de estado
-- (por ejemplo estado_transaccion con Completado / Pendiente / Cancelado),
-- contar las transacciones que corresponden a servicios.
-- Descomentar y ajustar el nombre de la columna si aplica:
--
-- SELECT
--     t.estado_transaccion       AS estado,
--     COUNT(DISTINCT t.id_transaccion) AS total_solicitudes_servicio
-- FROM transaccion t
-- JOIN detalle_transaccion d ON d.id_transaccion = t.id_transaccion
-- WHERE d.id_servicio IS NOT NULL
-- GROUP BY t.estado_transaccion
-- ORDER BY total_solicitudes_servicio DESC;


-- ---------------------------------------------------------------------------------------------------------------------------------
-- Script del Enunciado 8.2 — Función SUM: Recaudo Comercial Total por Categoría de Producto
-- Calcular el monto total acumulado ($) en ventas de productos pertenecientes a la categoría 'Libros' y 'Tecnología/Computadores'.
-- ---------------------------------------------------------------------------------------------------------------------------------

-- En el catálogo del equipo las categorías se llaman 'Libro' y 'Computador' (tabla tipo_producto).
-- Se parte de tipo_producto con LEFT JOIN para que ambas categorías aparezcan aunque no tengan ventas (monto 0).
SELECT
    tp.nombre_tipo_producto                                   AS categoria,
    COALESCE(SUM(d.cantidad * d.precio_unitario), 0)          AS recaudo_total
FROM tipo_producto tp
LEFT JOIN producto p            ON p.id_tipo_producto = tp.id_tipo_producto
LEFT JOIN detalle_transaccion d ON d.id_producto = p.id_producto
WHERE tp.nombre_tipo_producto IN ('Libro', 'Computador')
GROUP BY tp.nombre_tipo_producto
ORDER BY recaudo_total DESC;

-- Gran total de ambas categorías.
SELECT
    COALESCE(SUM(d.cantidad * d.precio_unitario), 0) AS recaudo_libros_y_computadores
FROM detalle_transaccion d
JOIN producto p        ON p.id_producto = d.id_producto
JOIN tipo_producto tp  ON tp.id_tipo_producto = p.id_tipo_producto
WHERE tp.nombre_tipo_producto IN ('Libro', 'Computador');
