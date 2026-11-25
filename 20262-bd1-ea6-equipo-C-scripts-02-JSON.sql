--
-- Scripts - Enunciados DML para Manipulación de Datos Semi-Estructurados (JSON)
-- Manipulación de Campo JSON (Perfil Profesional y Competencias)
--
-- Tabla: perfil (id_usuario, datos_perfil JSONB, fecha_actualizacion)
-- Los perfiles ya fueron poblados con: programa_academico, semestre,
-- intereses, habilidades y disponible_mentoria. Aquí se ENRIQUECE el
-- documento con: resumen, skills, areas_interes, idiomas y proyectos.
-- (El operador || conserva las claves existentes.)

------------------------------------------------------------------
-- 0. Verificar el estado actual del JSON y el tipo de columna
------------------------------------------------------------------
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'perfil' AND column_name = 'datos_perfil';

SELECT id_usuario, datos_perfil
FROM perfil
ORDER BY id_usuario
LIMIT 3;

------------------------------------------------------------------
-- 1. UPDATE: registrar resumen profesional, skills, áreas de interés,
--    idiomas y proyectos destacados para un usuario específico
------------------------------------------------------------------
UPDATE perfil
SET datos_perfil = datos_perfil::jsonb || '{
        "resumen_profesional": "Estudiante de Ingeniería de Software con enfoque en bases de datos y desarrollo web.",
        "skills": ["PostgreSQL", "Python", "SQL", "Git", "Modelado de datos"],
        "areas_interes": ["Ciencia de datos", "Inteligencia artificial", "Desarrollo backend"],
        "idiomas": [
            {"idioma": "Español", "nivel": "Nativo"},
            {"idioma": "Inglés",  "nivel": "B2"}
        ],
        "proyectos_destacados": [
            {"nombre": "Red Social Pascualina", "rol": "Diseñador de BD", "anio": 2026},
            {"nombre": "Sistema de Inventario",  "rol": "Desarrollador",   "anio": 2025}
        ]
    }'::jsonb,
    fecha_actualizacion = CURRENT_TIMESTAMP
WHERE id_usuario = 1;

------------------------------------------------------------------
-- 1.1 UPDATE masivo: completar los demás perfiles con valores aleatorios
------------------------------------------------------------------
UPDATE perfil
SET datos_perfil = datos_perfil::jsonb || jsonb_build_object(
        'resumen_profesional', 'Miembro de la comunidad Pascualina',
        'skills', jsonb_build_array(
            (ARRAY['SQL','Python','Java','Excel','Power BI','Docker'])[1 + floor(random()*6)::int],
            (ARRAY['Git','Linux','React','Node.js','Scrum','AWS'])[1 + floor(random()*6)::int]
        ),
        'areas_interes', jsonb_build_array(
            (ARRAY['IA','Redes','Seguridad','Bases de datos','Cloud'])[1 + floor(random()*5)::int]
        ),
        'idiomas', jsonb_build_array(
            jsonb_build_object('idioma','Español','nivel','Nativo'),
            jsonb_build_object('idioma','Inglés','nivel',
                (ARRAY['A2','B1','B2','C1'])[1 + floor(random()*4)::int])
        ),
        'proyectos_destacados', jsonb_build_array(
            jsonb_build_object('nombre','Proyecto de Aula','rol','Integrante',
                               'anio', 2024 + floor(random()*3)::int)
        )
    ),
    fecha_actualizacion = CURRENT_TIMESTAMP
WHERE id_usuario <> 1
  AND NOT (datos_perfil::jsonb ? 'skills');

------------------------------------------------------------------
-- 2. Modificación de datos JSON (UPDATE parcial con jsonb_set)
------------------------------------------------------------------
-- 2.1 Subir el nivel de inglés (segundo elemento del arreglo idiomas)
UPDATE perfil
SET datos_perfil = jsonb_set(datos_perfil::jsonb, '{idiomas,1,nivel}', '"C1"')
WHERE id_usuario = 1;

-- 2.2 Agregar una nueva habilidad al arreglo skills
UPDATE perfil
SET datos_perfil = jsonb_set(
        datos_perfil::jsonb, '{skills}',
        (datos_perfil::jsonb -> 'skills') || '"Docker"'::jsonb)
WHERE id_usuario = 1;

-- 2.3 Agregar una nueva clave al documento
UPDATE perfil
SET datos_perfil = datos_perfil::jsonb ||
        '{"certificaciones": ["PostgreSQL Fundamentals"]}'::jsonb
WHERE id_usuario = 1;

------------------------------------------------------------------
-- 3. Eliminación de datos JSON
------------------------------------------------------------------
-- 3.1 Eliminar una clave completa
UPDATE perfil
SET datos_perfil = datos_perfil::jsonb - 'certificaciones'
WHERE id_usuario = 1;

-- 3.2 Eliminar el primer elemento del arreglo skills (índice 0)
UPDATE perfil
SET datos_perfil = datos_perfil::jsonb #- '{skills,0}'
WHERE id_usuario = 1;

------------------------------------------------------------------
-- 4. CONSULTA PRINCIPAL (pantallazo del informe):
--    extraer elementos específicos del documento JSON
--    ->  devuelve JSON | ->> devuelve texto | #>> ruta anidada
------------------------------------------------------------------
SELECT
    p.id_usuario,
    p.datos_perfil ->> 'programa_academico'                         AS programa_academico,
    p.datos_perfil ->> 'resumen_profesional'                        AS resumen_profesional,
    p.datos_perfil -> 'skills'                                      AS skills,
    p.datos_perfil -> 'skills' ->> 0                                AS primera_skill,
    jsonb_array_length(p.datos_perfil::jsonb -> 'skills')           AS total_skills,
    p.datos_perfil -> 'areas_interes'                               AS areas_interes,
    p.datos_perfil #>> '{idiomas,1,idioma}'                         AS segundo_idioma,
    p.datos_perfil #>> '{idiomas,1,nivel}'                          AS nivel_segundo_idioma,
    p.datos_perfil #>> '{proyectos_destacados,0,nombre}'            AS proyecto_principal
FROM perfil p
WHERE p.id_usuario = 1;

------------------------------------------------------------------
-- 5. CONSULTAS de apoyo (para el video): filtro y desanidado de arreglos
------------------------------------------------------------------
-- 5.1 Perfiles que dominan SQL (operador de contención @>)
SELECT id_usuario, datos_perfil -> 'skills' AS skills
FROM perfil
WHERE datos_perfil::jsonb -> 'skills' @> '["SQL"]'::jsonb
LIMIT 20;

-- 5.2 Ranking de skills más frecuentes en la red
SELECT s.skill, COUNT(*) AS total_perfiles
FROM perfil p,
     jsonb_array_elements_text(p.datos_perfil::jsonb -> 'skills') AS s(skill)
GROUP BY s.skill
ORDER BY total_perfiles DESC
LIMIT 10;

-- 5.3 Perfiles con inglés B2 o superior
SELECT p.id_usuario, i ->> 'nivel' AS nivel_ingles
FROM perfil p,
     jsonb_array_elements(p.datos_perfil::jsonb -> 'idiomas') AS i
WHERE i ->> 'idioma' = 'Inglés'
  AND i ->> 'nivel' IN ('B2','C1')
LIMIT 20;

------------------------------------------------------------------
-- 6. (Opcional) Índice GIN para acelerar búsquedas dentro del JSON
--    Solo funciona directo si la columna es JSONB.
------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_perfil_datos_perfil_gin
    ON perfil USING GIN ((datos_perfil::jsonb));


