-- Equipo C - Base de Datos I (SD1006) - Red Social Pascualina - PostgreSQL
--
-- SUPUESTO IMPORTANTE: el enunciado del ítem 7 no estaba disponible. Se asumió una consulta con
-- 4 JOINs, GROUP BY y HAVING sobre ventas de productos:
--   "Recaudo por tipo de producto y medio de pago, mostrando solo las combinaciones
--    cuyo recaudo supere un umbral."
-- Si el ítem 7 es otro, reemplazar el SELECT de la vista (9), del PREPARE (10) y del EXPLAIN (11).
-- Los nombres de tablas y columnas se tomaron del script 01 (poblamiento).

-- ---------------------------------------------------------------------------------------------------------------------------------
-- 9.- Enunciado para creación de Vista (VIEW) con 4 JOINs, GROUP BY y HAVING
-- Construya una vista (VIEW) con el enunciado del ítem 7. Debe crear la vista (darle un nombre) y ejecutarla.
-- ---------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW vw_recaudo_producto_por_tipo_y_medio_pago AS
SELECT
    tp.nombre_tipo_producto                       AS tipo_producto,
    mp.nombre_medio_pago                          AS medio_pago,
    COUNT(DISTINCT t.id_transaccion)              AS num_transacciones,
    SUM(d.cantidad)                               AS unidades_vendidas,
    SUM(d.cantidad * d.precio_unitario)           AS recaudo_total
FROM detalle_transaccion d
JOIN transaccion   t  ON t.id_transaccion   = d.id_transaccion      -- JOIN 1
JOIN producto      p  ON p.id_producto      = d.id_producto         -- JOIN 2
JOIN tipo_producto tp ON tp.id_tipo_producto = p.id_tipo_producto   -- JOIN 3
JOIN medio_pago    mp ON mp.id_medio_pago   = t.id_medio_pago       -- JOIN 4
GROUP BY tp.nombre_tipo_producto, mp.nombre_medio_pago
HAVING SUM(d.cantidad * d.precio_unitario) > 50000;

-- Ejecución de la vista
SELECT * FROM vw_recaudo_producto_por_tipo_y_medio_pago
ORDER BY recaudo_total DESC;

-- Ejecución con filtro adicional sobre la vista
SELECT tipo_producto, SUM(recaudo_total) AS recaudo
FROM vw_recaudo_producto_por_tipo_y_medio_pago
GROUP BY tipo_producto
ORDER BY recaudo DESC;


-- ---------------------------------------------------------------------------------------------------------------------------------
-- 10.- Ejercicio del enunciado para consulta parametrizada (PREPARE / EXECUTE) con 4 JOINs (GROUP BY y HAVING)
-- ---------------------------------------------------------------------------------------------------------------------------------

-- Parámetros: $1 = recaudo mínimo (numeric), $2 = nombre del medio de pago (text)
DEALLOCATE ALL;

PREPARE recaudo_por_tipo (numeric, text) AS
SELECT
    tp.nombre_tipo_producto                       AS tipo_producto,
    mp.nombre_medio_pago                          AS medio_pago,
    COUNT(DISTINCT t.id_transaccion)              AS num_transacciones,
    SUM(d.cantidad * d.precio_unitario)           AS recaudo_total
FROM detalle_transaccion d
JOIN transaccion   t  ON t.id_transaccion   = d.id_transaccion
JOIN producto      p  ON p.id_producto      = d.id_producto
JOIN tipo_producto tp ON tp.id_tipo_producto = p.id_tipo_producto
JOIN medio_pago    mp ON mp.id_medio_pago   = t.id_medio_pago
WHERE mp.nombre_medio_pago = $2
GROUP BY tp.nombre_tipo_producto, mp.nombre_medio_pago
HAVING SUM(d.cantidad * d.precio_unitario) > $1
ORDER BY recaudo_total DESC;

-- Ejecuciones con distintos valores de parámetros
EXECUTE recaudo_por_tipo(10000,  'Efectivo');
EXECUTE recaudo_por_tipo(50000,  'Transferencia Nequi');
EXECUTE recaudo_por_tipo(100000, 'PSE');

-- Consultar las sentencias preparadas de la sesión
SELECT name, statement, parameter_types FROM pg_prepared_statements;

DEALLOCATE recaudo_por_tipo;


-- ---------------------------------------------------------------------------------------------------------------------------------
--11.- Ejercicio del enunciado para Evaluación Experimental de Rendimiento con ANALYZE
-- ---------------------------------------------------------------------------------------------------------------------------------

-- Paso 0: actualizar estadísticas del optimizador
ANALYZE detalle_transaccion;
ANALYZE transaccion;
ANALYZE producto;
ANALYZE tipo_producto;
ANALYZE medio_pago;

-- Paso 1: plan SIN índices adicionales (línea base). Anotar "Execution Time" y tipo de scan.
DROP INDEX IF EXISTS idx_detalle_id_producto;
DROP INDEX IF EXISTS idx_detalle_id_transaccion;
DROP INDEX IF EXISTS idx_producto_id_tipo;
DROP INDEX IF EXISTS idx_transaccion_id_medio_pago;

EXPLAIN (ANALYZE, BUFFERS)
SELECT tp.nombre_tipo_producto, mp.nombre_medio_pago,
       SUM(d.cantidad * d.precio_unitario) AS recaudo_total
FROM detalle_transaccion d
JOIN transaccion   t  ON t.id_transaccion   = d.id_transaccion
JOIN producto      p  ON p.id_producto      = d.id_producto
JOIN tipo_producto tp ON tp.id_tipo_producto = p.id_tipo_producto
JOIN medio_pago    mp ON mp.id_medio_pago   = t.id_medio_pago
GROUP BY tp.nombre_tipo_producto, mp.nombre_medio_pago
HAVING SUM(d.cantidad * d.precio_unitario) > 50000;

-- Paso 2: crear índices sobre las columnas de unión (PostgreSQL NO indexa automáticamente las FK)
CREATE INDEX idx_detalle_id_producto      ON detalle_transaccion (id_producto);
CREATE INDEX idx_detalle_id_transaccion   ON detalle_transaccion (id_transaccion);
CREATE INDEX idx_producto_id_tipo         ON producto (id_tipo_producto);
CREATE INDEX idx_transaccion_id_medio_pago ON transaccion (id_medio_pago);

ANALYZE detalle_transaccion;
ANALYZE transaccion;
ANALYZE producto;

-- Paso 3: mismo plan CON índices. Comparar tiempos, tipo de scan y buffers contra el Paso 1.
EXPLAIN (ANALYZE, BUFFERS)
SELECT tp.nombre_tipo_producto, mp.nombre_medio_pago,
       SUM(d.cantidad * d.precio_unitario) AS recaudo_total
FROM detalle_transaccion d
JOIN transaccion   t  ON t.id_transaccion   = d.id_transaccion
JOIN producto      p  ON p.id_producto      = d.id_producto
JOIN tipo_producto tp ON tp.id_tipo_producto = p.id_tipo_producto
JOIN medio_pago    mp ON mp.id_medio_pago   = t.id_medio_pago
GROUP BY tp.nombre_tipo_producto, mp.nombre_medio_pago
HAVING SUM(d.cantidad * d.precio_unitario) > 50000;

-- Paso 4 (opcional): con tablas pequeñas (100 transacciones) el optimizador puede seguir eligiendo
-- Seq Scan aunque exista el índice, porque es más barato. Para evidenciar el uso del índice:
-- SET enable_seqscan = off;
-- (repetir el EXPLAIN ANALYZE del Paso 3)
-- RESET enable_seqscan;

-- Paso 5 (opcional): consulta selectiva donde el índice sí suele usarse
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM detalle_transaccion WHERE id_producto = 1;


-- ---------------------------------------------------------------------------------------------------------------------------------
-- 12.- Enunciado para Validación de Propiedades ACID en 4 Tablas del DDL
-- Tablas usadas: usuario, producto, transaccion, detalle_transaccion
-- ---------------------------------------------------------------------------------------------------------------------------------
-- 12.1.- Atomicidad (Atomicity): Demostrar que una compra de un producto que falla en medio de la transacción por 
-- saldo  insuficiente o error de clave foránea revierte absolutamente todas las operaciones previas mediante ROLLBACK, 
-- dejando las tablas intactas.
-- ---------------------------------------------------------------------------------------------------------------------------------

-- Estado ANTES
SELECT (SELECT COUNT(*) FROM transaccion)         AS transacciones_antes,
       (SELECT COUNT(*) FROM detalle_transaccion) AS detalles_antes;

BEGIN;

-- Operación 1 (válida): se crea la transacción de compra
INSERT INTO transaccion (id_usuario_comprador, id_medio_pago, monto_total, fecha_transaccion)
SELECT u.id_usuario, 1, 20000, CURRENT_TIMESTAMP
FROM usuario u
WHERE u.id_rol = 3
ORDER BY u.id_usuario
LIMIT 1;

-- Dentro de la transacción se ve la fila nueva
SELECT COUNT(*) AS transacciones_dentro_de_la_tx FROM transaccion;

-- Operación 2 (FALLA): producto inexistente -> viola la clave foránea
INSERT INTO detalle_transaccion (id_transaccion, id_producto, id_servicio, cantidad, precio_unitario)
VALUES ((SELECT MAX(id_transaccion) FROM transaccion), -999, NULL, 1, 20000);
-- ERROR: insert or update on table "detalle_transaccion" violates foreign key constraint

-- La transacción queda abortada; se revierte TODO, incluida la Operación 1
ROLLBACK;

-- Estado DESPUÉS: debe ser idéntico al estado ANTES
SELECT (SELECT COUNT(*) FROM transaccion)         AS transacciones_despues,
       (SELECT COUNT(*) FROM detalle_transaccion) AS detalles_despues;

-- Variante "saldo insuficiente": la base no tiene columna de saldo, por lo que se simula con una
-- validación de negocio. El bloque DO es atómico: al lanzar la excepción se revierte todo lo anterior.
DO $$
DECLARE
    v_saldo_comprador NUMERIC := 5000;   -- saldo simulado
    v_monto           NUMERIC := 20000;
    v_comprador       BIGINT;
BEGIN
    SELECT id_usuario INTO v_comprador FROM usuario WHERE id_rol = 3 ORDER BY id_usuario LIMIT 1;

    INSERT INTO transaccion (id_usuario_comprador, id_medio_pago, monto_total, fecha_transaccion)
    VALUES (v_comprador, 1, v_monto, CURRENT_TIMESTAMP);

    IF v_saldo_comprador < v_monto THEN
        RAISE EXCEPTION 'Saldo insuficiente: % < %', v_saldo_comprador, v_monto;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Compra revertida: %', SQLERRM;
END $$;

-- Verificación: el conteo de transacciones sigue igual que "antes"
SELECT COUNT(*) AS transacciones_tras_saldo_insuficiente FROM transaccion;


-- ---------------------------------------------------------------------------------------------------------------------------------
-- 12.2.- Consistencia (Consistency): Demostrar cómo las restricciones de integridad física (CHECK precio >= 0, FOREIGN KEY, NOT NULL) 
-- impiden que la base de datos ingrese a un estado de datos inconsistente o embasurado.
-- ---------------------------------------------------------------------------------------------------------------------------------

-- Cada intento se ejecuta en su propio bloque para que el script continúe y muestre el error capturado.

-- (a) CHECK: precio negativo
DO $$
BEGIN
    INSERT INTO producto (id_usuario_vendedor, id_tipo_producto, nombre_producto, precio_producto)
    VALUES ((SELECT MIN(id_usuario) FROM usuario WHERE id_rol = 3), 1, 'Producto con precio negativo', -5000);
    RAISE NOTICE 'ATENCIÓN: se aceptó un precio negativo (falta el CHECK en el DDL)';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'CHECK rechazó el dato [%]: %', SQLSTATE, SQLERRM;
END $$;

-- (b) FOREIGN KEY: producto con tipo de producto inexistente
DO $$
BEGIN
    INSERT INTO producto (id_usuario_vendedor, id_tipo_producto, nombre_producto, precio_producto)
    VALUES ((SELECT MIN(id_usuario) FROM usuario WHERE id_rol = 3), 9999, 'Producto con tipo inexistente', 10000);
    RAISE NOTICE 'ATENCIÓN: se aceptó una FK inválida';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'FOREIGN KEY rechazó el dato [%]: %', SQLSTATE, SQLERRM;
END $$;

-- (c) NOT NULL: usuario sin correo electrónico
DO $$
BEGIN
    INSERT INTO usuario (id_rol, id_tipo_usuario, nombre_usuario, correo_electronico, contrasena_hash, fecha_registro)
    VALUES (3, 1, 'usuario_sin_correo', NULL, md5('x'), CURRENT_TIMESTAMP);
    RAISE NOTICE 'ATENCIÓN: se aceptó un usuario sin correo';
EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'NOT NULL rechazó el dato [%]: %', SQLSTATE, SQLERRM;
END $$;

-- (d) FOREIGN KEY: detalle de transacción con transacción inexistente
DO $$
BEGIN
    INSERT INTO detalle_transaccion (id_transaccion, id_producto, id_servicio, cantidad, precio_unitario)
    VALUES (-1, (SELECT MIN(id_producto) FROM producto), NULL, 1, 10000);
    RAISE NOTICE 'ATENCIÓN: se aceptó un detalle huérfano';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'FOREIGN KEY rechazó el detalle huérfano [%]: %', SQLSTATE, SQLERRM;
END $$;

-- Verificación: no quedó ningún dato inconsistente
SELECT COUNT(*) AS productos_con_precio_negativo FROM producto WHERE precio_producto < 0;
SELECT COUNT(*) AS productos_sin_tipo_valido
FROM producto p LEFT JOIN tipo_producto tp ON tp.id_tipo_producto = p.id_tipo_producto
WHERE tp.id_tipo_producto IS NULL;
SELECT COUNT(*) AS detalles_huerfanos
FROM detalle_transaccion d LEFT JOIN transaccion t ON t.id_transaccion = d.id_transaccion
WHERE t.id_transaccion IS NULL;

-- Listar las restricciones físicas que protegen las 4 tablas
SELECT conrelid::regclass AS tabla, conname AS restriccion,
       CASE contype WHEN 'p' THEN 'PRIMARY KEY' WHEN 'f' THEN 'FOREIGN KEY'
                    WHEN 'c' THEN 'CHECK' WHEN 'u' THEN 'UNIQUE' END AS tipo
FROM pg_constraint
WHERE conrelid IN ('usuario'::regclass, 'producto'::regclass,
                   'transaccion'::regclass, 'detalle_transaccion'::regclass)
ORDER BY tabla, tipo;


-- ---------------------------------------------------------------------------------------------------------------------------------
-- 12.3.- Aislamiento (Isolation)
-- NOTA: la plantilla del docente salta de 12.2 a 12.4. Se incluye 12.3 por completitud de ACID;
-- confirmar con el docente si se debe entregar.
-- Requiere DOS sesiones (dos pestañas de psql/pgAdmin). Ejecutar en el orden indicado.
-- ---------------------------------------------------------------------------------------------------------------------------------

-- ===== SESIÓN A =====
-- BEGIN;
-- UPDATE producto SET precio_producto = precio_producto + 1000 WHERE id_producto = 1;
-- SELECT id_producto, precio_producto FROM producto WHERE id_producto = 1;   -- ve el precio NUEVO

-- ===== SESIÓN B (mientras A no ha hecho COMMIT) =====
-- SELECT id_producto, precio_producto FROM producto WHERE id_producto = 1;   -- ve el precio ANTERIOR (sin lecturas sucias)

-- ===== SESIÓN A =====
-- COMMIT;

-- ===== SESIÓN B =====
-- SELECT id_producto, precio_producto FROM producto WHERE id_producto = 1;   -- ahora ve el precio NUEVO (READ COMMITTED)

-- Prueba con REPEATABLE READ (lectura repetible):
-- ===== SESIÓN B =====
-- BEGIN ISOLATION LEVEL REPEATABLE READ;
-- SELECT precio_producto FROM producto WHERE id_producto = 1;                -- lectura 1
-- ===== SESIÓN A =====
-- UPDATE producto SET precio_producto = precio_producto + 1000 WHERE id_producto = 1;   -- (autocommit)
-- ===== SESIÓN B =====
-- SELECT precio_producto FROM producto WHERE id_producto = 1;                -- lectura 2: MISMO valor que la lectura 1
-- COMMIT;
-- SELECT precio_producto FROM producto WHERE id_producto = 1;                -- ya fuera de la tx: ve el valor actualizado

-- Restaurar el precio original si se desea:
-- UPDATE producto SET precio_producto = precio_producto - 2000 WHERE id_producto = 1;


-- ---------------------------------------------------------------------------------------------------------------------------------
-- 12.4.- Durabilidad (Durability): Demostrar que una vez ejecutado exitosamente el comando COMMIT, los datos persisten de manera 
-- permanente en el almacenamiento físico de PostgreSQL (archivos WAL) incluso ante una simulación de desconexión imprevista del servidor.
-- ---------------------------------------------------------------------------------------------------------------------------------

-- Parámetros que garantizan la durabilidad (deben estar en on / valor por defecto)
SHOW fsync;
SHOW synchronous_commit;
SHOW wal_level;

-- Posición del WAL ANTES del commit
SELECT pg_current_wal_lsn() AS lsn_antes, pg_walfile_name(pg_current_wal_lsn()) AS archivo_wal_antes;

BEGIN;
WITH prod AS (
    SELECT id_producto, id_usuario_vendedor, precio_producto
    FROM producto ORDER BY id_producto LIMIT 1
), comp AS (
    SELECT id_usuario FROM usuario
    WHERE id_rol = 3 AND id_usuario <> (SELECT id_usuario_vendedor FROM prod)
    ORDER BY id_usuario LIMIT 1
), t AS (
    INSERT INTO transaccion (id_usuario_comprador, id_medio_pago, monto_total, fecha_transaccion)
    SELECT comp.id_usuario, 1, prod.precio_producto * 2, CURRENT_TIMESTAMP
    FROM prod, comp
    RETURNING id_transaccion
)
INSERT INTO detalle_transaccion (id_transaccion, id_producto, id_servicio, cantidad, precio_unitario)
SELECT t.id_transaccion, prod.id_producto, NULL, 2, prod.precio_producto
FROM t, prod;
COMMIT;

-- Registro del último dato confirmado y posición del WAL DESPUÉS del commit (el LSN avanzó)
SELECT t.id_transaccion, t.monto_total, d.id_producto, d.cantidad
FROM transaccion t
JOIN detalle_transaccion d ON d.id_transaccion = t.id_transaccion
ORDER BY t.id_transaccion DESC LIMIT 1;

SELECT pg_current_wal_lsn() AS lsn_despues, pg_walfile_name(pg_current_wal_lsn()) AS archivo_wal_despues;

-- Simulación de desconexión imprevista: se termina abruptamente el proceso de esta sesión.
-- psql mostrará "server closed the connection unexpectedly" y se reconectará en el siguiente comando.
SELECT pg_terminate_backend(pg_backend_pid());

-- (Opcional, simulación más fuerte: caída del servidor sin apagado ordenado, desde la terminal del SO)
--   pg_ctl restart -m immediate -D <ruta_del_data_directory>
-- Al reiniciar, PostgreSQL reproduce el WAL (crash recovery) y los datos confirmados siguen ahí.

-- Tras reconectar: el dato confirmado con COMMIT sigue presente
SELECT t.id_transaccion, t.monto_total, d.id_producto, d.cantidad
FROM transaccion t
JOIN detalle_transaccion d ON d.id_transaccion = t.id_transaccion
ORDER BY t.id_transaccion DESC LIMIT 1;
