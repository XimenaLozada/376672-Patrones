-- =====================================================================
-- RESULTADOS PARA LLENAR EL INFORME
-- Corre cada bloque (A a F) en DBeaver con Ctrl+Enter y copia o exporta
-- el resultado. Si una consulta marca error de columna en las tablas de
-- gasolina o noticias, corre primero el bloque 0 y ajusta los nombres.
-- =====================================================================

-- 0. Nombres reales de columnas (solo si algo falla)
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('precio_gasolina_estado','noticia','noticia_geo','noticia_scian','diagnostico_calidad')
ORDER BY table_name, ordinal_position;


-- A. Totales del DENUE y calidad de datos  (secciones 4.3 y 7.1)
SELECT
    COUNT(*)                                                             AS total_denue,
    COUNT(*) FILTER (WHERE codigo_act IN (464111,464112))                AS farmacias,
    COUNT(*) FILTER (WHERE codigo_act::text LIKE '6211%')                AS consultorios,
    COUNT(*) FILTER (WHERE codigo_act::text LIKE '6215%')                AS laboratorios,
    COUNT(*) FILTER (WHERE codigo_act::text LIKE '622%')                 AS hospitales,
    MIN(fecha_alta)                                                      AS primera_alta,
    MAX(fecha_alta)                                                      AS ultima_alta,
    COUNT(*) FILTER (WHERE codigo_act IN (464111,464112)
                     AND (raz_social IS NULL OR TRIM(raz_social) = ''))  AS farmacias_sin_razon_social,
    COUNT(*) FILTER (WHERE codigo_act IN (464111,464112)
                     AND nom_estab ILIKE '%SIN NOMBRE%')                 AS farmacias_sin_nombre,
    COUNT(*) - COUNT(DISTINCT clee)                                      AS registros_duplicados
FROM denue_inegi_oficial;


-- B. Vista base por municipio (si ya la creaste antes, puedes saltarte este bloque)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_municipio_salud AS
SELECT cve_ent, entidad, cve_mun, municipio,
       COUNT(*)                                                       AS total_negocios,
       COUNT(*) FILTER (WHERE codigo_act IN (464111,464112))          AS farmacias,
       COUNT(*) FILTER (WHERE codigo_act::text LIKE '6211%')          AS consultorios,
       COUNT(*) FILTER (WHERE codigo_act::text LIKE '6215%')          AS laboratorios,
       COUNT(*) FILTER (WHERE codigo_act::text LIKE '622%')           AS hospitales,
       COUNT(*) FILTER (WHERE codigo_act = 462112)                    AS minisupers
FROM denue_inegi_oficial
GROUP BY cve_ent, entidad, cve_mun, municipio;


-- C. Ranking con TODOS los indicadores  (hallazgos 1 a 6, secciones 8 y 9)
--    La última fila (lugar = 0) es el PROMEDIO de todos los municipios analizados.
WITH farm AS (
    SELECT cve_ent, cve_mun,
           ROUND(100.0 * COUNT(*) FILTER (WHERE per_ocu ILIKE '0 a 5%') / COUNT(*), 1) AS pct_pequenas,
           ROUND(100.0 * COUNT(*) FILTER (WHERE LEFT(fecha_alta,4) >= '2020') / COUNT(*), 1) AS pct_recientes
    FROM denue_inegi_oficial
    WHERE codigo_act IN (464111,464112)
    GROUP BY cve_ent, cve_mun
),
gas AS (
    SELECT cve_ent, AVG(precio) AS gasolina_12m
    FROM precio_gasolina_estado
    WHERE fecha >= (SELECT MAX(fecha) FROM precio_gasolina_estado) - INTERVAL '12 months'
    GROUP BY cve_ent
),
base AS (
    SELECT m.*, f.pct_pequenas, f.pct_recientes, g.gasolina_12m,
           farmacias * 1000.0 / total_negocios                                AS saturacion,
           (consultorios + laboratorios + hospitales)::numeric / farmacias     AS demanda,
           LN(total_negocios::numeric)                                         AS mercado
    FROM mv_municipio_salud m
    JOIN farm f USING (cve_ent, cve_mun)
    LEFT JOIN gas g USING (cve_ent)
    WHERE total_negocios >= 2000 AND farmacias > 0
),
idx AS (
    SELECT *,
      100 * ( 0.40 * (demanda - MIN(demanda) OVER()) / NULLIF(MAX(demanda) OVER() - MIN(demanda) OVER(),0)
            + 0.35 * (1 - (saturacion - MIN(saturacion) OVER()) / NULLIF(MAX(saturacion) OVER() - MIN(saturacion) OVER(),0))
            + 0.25 * (mercado - MIN(mercado) OVER()) / NULLIF(MAX(mercado) OVER() - MIN(mercado) OVER(),0)) AS indice
    FROM base
),
ranked AS (
    SELECT RANK() OVER (ORDER BY indice DESC) AS lugar, * FROM idx
)
SELECT lugar, entidad, municipio, cve_ent, cve_mun, total_negocios, farmacias,
       consultorios, laboratorios, hospitales,
       ROUND(saturacion,2) AS farmacias_por_mil, ROUND(demanda,2) AS salud_por_farmacia,
       pct_pequenas, pct_recientes, ROUND(gasolina_12m::numeric,2) AS gasolina_12m,
       ROUND(indice::numeric,1) AS indice
FROM ranked WHERE lugar <= 15
UNION ALL
SELECT 0, 'PROMEDIO', 'TODOS', NULL, NULL, ROUND(AVG(total_negocios)), ROUND(AVG(farmacias)),
       ROUND(AVG(consultorios)), ROUND(AVG(laboratorios)), ROUND(AVG(hospitales)),
       ROUND(AVG(saturacion),2), ROUND(AVG(demanda),2), ROUND(AVG(pct_pequenas),1),
       ROUND(AVG(pct_recientes),1), ROUND(AVG(gasolina_12m)::numeric,2), ROUND(AVG(indice)::numeric,1)
FROM ranked
ORDER BY lugar = 0, lugar;


-- D. Municipios con más aperturas recientes  (hallazgo 5)
SELECT entidad, municipio, COUNT(*) AS farmacias,
       ROUND(100.0 * COUNT(*) FILTER (WHERE LEFT(fecha_alta,4) >= '2020') / COUNT(*), 1) AS pct_recientes
FROM denue_inegi_oficial
WHERE codigo_act IN (464111,464112)
GROUP BY entidad, municipio
HAVING COUNT(*) >= 20
ORDER BY pct_recientes DESC
LIMIT 5;


-- E. Gasolina y noticias: periodo, registros y noticias de los 3 primeros  (4.3 y hallazgo 7)
SELECT 'gasolina' AS tabla, COUNT(*) AS registros, MIN(fecha)::text AS desde, MAX(fecha)::text AS hasta,
       ROUND(AVG(precio) FILTER (WHERE fecha >= (SELECT MAX(fecha) FROM precio_gasolina_estado) - INTERVAL '12 months')::numeric,2)::text AS promedio_nacional_12m
FROM precio_gasolina_estado
UNION ALL
SELECT 'noticias', COUNT(*), MIN(fecha)::text, MAX(fecha)::text, NULL FROM noticia;

-- Cambia los números de cve_ent y cve_mun por los de los 3 primeros lugares del bloque C
SELECT g.cve_ent, g.cve_mun,
       COUNT(DISTINCT n.id)                       AS noticias,
       ROUND(AVG(n.sentimiento)::numeric, 2)      AS sentimiento_promedio,
       COUNT(*) FILTER (WHERE n.sentimiento < 0)  AS negativas
FROM noticia n
JOIN noticia_geo   g ON g.noticia_id = n.id
JOIN noticia_scian s ON s.noticia_id = n.id
WHERE (s.codigo_scian::text LIKE '46%' OR s.codigo_scian::text LIKE '62%')
  AND n.fecha >= CURRENT_DATE - INTERVAL '12 months'
  AND (g.cve_ent, g.cve_mun) IN ((0,0), (0,0), (0,0))   -- <- reemplazar
GROUP BY g.cve_ent, g.cve_mun;


-- F. Problemas de calidad documentados  (tabla 7.1)
SELECT * FROM diagnostico_calidad;
