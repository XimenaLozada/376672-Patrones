-- =====================================================================
-- Propuesta: ¿Dónde abrir la próxima sucursal de una cadena de farmacias?
-- Motor: PostgreSQL (DBeaver)  |  Tabla principal: public.denue_inegi_oficial
-- Códigos SCIAN usados:
--   464111 Farmacias sin minisúper      464112 Farmacias con minisúper
--   6211xx Consultorios médicos         6215xx Laboratorios médicos y de diagnóstico
--   622xxx Hospitales                   462112 Minisúper (tiendas de conveniencia)
-- NOTA: las tablas noticia*, precio_gasolina_estado, cat_* y diagnostico_calidad
-- se escribieron con nombres de columna supuestos. Corre primero la consulta 0
-- y ajusta los nombres si no coinciden.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Revisar columnas reales de las tablas fuera del DENUE
-- ---------------------------------------------------------------------
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('cat_municipio','cat_scian','noticia','noticia_geo',
                     'noticia_scian','precio_referencia','precio_gasolina_estado',
                     'dim_tiempo','diagnostico_calidad')
ORDER BY table_name, ordinal_position;


-- ---------------------------------------------------------------------
-- 1. CALIDAD DE DATOS (problemas reales)
-- ---------------------------------------------------------------------
-- 1a. Problemas ya documentados
SELECT * FROM diagnostico_calidad;

-- 1b. Campos vacíos o poco confiables en los registros que usamos
SELECT
    COUNT(*)                                                         AS total_registros,
    SUM(CASE WHEN raz_social IS NULL OR TRIM(raz_social) = '' THEN 1 ELSE 0 END) AS sin_razon_social,
    SUM(CASE WHEN nom_estab ILIKE '%SIN NOMBRE%' THEN 1 ELSE 0 END)  AS nombre_sin_nombre,
    SUM(CASE WHEN latitud IS NULL OR longitud IS NULL
              OR latitud = 0 OR longitud = 0 THEN 1 ELSE 0 END)      AS sin_coordenadas,
    SUM(CASE WHEN fecha_alta IS NULL OR TRIM(fecha_alta) = '' THEN 1 ELSE 0 END) AS sin_fecha_alta
FROM denue_inegi_oficial
WHERE codigo_act IN (464111, 464112);

-- 1c. Establecimientos duplicados (misma clave CLEE)
SELECT clee, COUNT(*) AS veces
FROM denue_inegi_oficial
GROUP BY clee
HAVING COUNT(*) > 1
ORDER BY veces DESC
LIMIT 20;


-- ---------------------------------------------------------------------
-- 2. VISTA BASE: indicadores por municipio (se reutiliza en todo)
-- ---------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_municipio_salud;
CREATE MATERIALIZED VIEW mv_municipio_salud AS
SELECT
    cve_ent,
    entidad,
    cve_mun,
    municipio,
    COUNT(*)                                                                  AS total_negocios,
    COUNT(*) FILTER (WHERE codigo_act IN (464111, 464112))                    AS farmacias,
    COUNT(*) FILTER (WHERE codigo_act::text LIKE '6211%')                     AS consultorios,
    COUNT(*) FILTER (WHERE codigo_act::text LIKE '6215%')                     AS laboratorios,
    COUNT(*) FILTER (WHERE codigo_act::text LIKE '622%')                      AS hospitales,
    COUNT(*) FILTER (WHERE codigo_act = 462112)                               AS minisupers
FROM denue_inegi_oficial
GROUP BY cve_ent, entidad, cve_mun, municipio;

-- ---------------------------------------------------------------------
-- HALLAZGO 1. Farmacias por cada 1,000 negocios (saturación del mercado)
-- Técnica: agregación + tasa normalizada
-- ---------------------------------------------------------------------
SELECT entidad, municipio, total_negocios, farmacias,
       ROUND(farmacias * 1000.0 / NULLIF(total_negocios,0), 2) AS farmacias_por_mil_negocios
FROM mv_municipio_salud
WHERE total_negocios >= 2000          -- solo municipios con mercado suficiente
ORDER BY farmacias_por_mil_negocios ASC
LIMIT 20;

-- ---------------------------------------------------------------------
-- HALLAZGO 2. Consultorios por farmacia (demanda de recetas sin surtir)
-- Técnica: razón entre complementos y competidores
-- ---------------------------------------------------------------------
SELECT entidad, municipio, consultorios, laboratorios, hospitales, farmacias,
       ROUND((consultorios + laboratorios + hospitales)::numeric
             / NULLIF(farmacias,0), 2) AS servicios_salud_por_farmacia
FROM mv_municipio_salud
WHERE total_negocios >= 2000 AND farmacias > 0
ORDER BY servicios_salud_por_farmacia DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- HALLAZGO 3. Tamaño de las farmacias existentes (competencia fragmentada)
-- Técnica: segmentación / distribución por categoría de per_ocu
-- ---------------------------------------------------------------------
SELECT m.entidad, m.municipio,
       COUNT(*)                                                   AS farmacias,
       COUNT(*) FILTER (WHERE d.per_ocu ILIKE '0 a 5%')           AS farmacias_0a5_personas,
       ROUND(100.0 * COUNT(*) FILTER (WHERE d.per_ocu ILIKE '0 a 5%')
             / COUNT(*), 1)                                       AS pct_pequenas
FROM denue_inegi_oficial d
JOIN mv_municipio_salud m
  ON m.cve_ent = d.cve_ent AND m.cve_mun = d.cve_mun
WHERE d.codigo_act IN (464111, 464112)
  AND m.total_negocios >= 2000
GROUP BY m.entidad, m.municipio
ORDER BY pct_pequenas DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- HALLAZGO 4. Índice de oportunidad (ranking final de municipios)
-- Técnica: normalización min-max + índice ponderado + RANK()
-- Pesos: 40% demanda de salud, 35% poca competencia, 25% tamaño de mercado
-- ---------------------------------------------------------------------
WITH base AS (
    SELECT *,
           (consultorios + laboratorios + hospitales)::numeric
               / NULLIF(farmacias,0)                          AS demanda,
           farmacias * 1000.0 / NULLIF(total_negocios,0)      AS saturacion,
           total_negocios::numeric                            AS mercado
    FROM mv_municipio_salud
    WHERE total_negocios >= 2000 AND farmacias > 0
),
norm AS (
    SELECT *,
      (demanda - MIN(demanda) OVER()) / NULLIF(MAX(demanda) OVER() - MIN(demanda) OVER(),0)          AS n_demanda,
      1 - (saturacion - MIN(saturacion) OVER()) / NULLIF(MAX(saturacion) OVER() - MIN(saturacion) OVER(),0) AS n_poca_comp,
      (LN(mercado) - MIN(LN(mercado)) OVER()) / NULLIF(MAX(LN(mercado)) OVER() - MIN(LN(mercado)) OVER(),0) AS n_mercado
    FROM base
)
SELECT RANK() OVER (ORDER BY 0.40*n_demanda + 0.35*n_poca_comp + 0.25*n_mercado DESC) AS lugar,
       cve_ent, entidad, cve_mun, municipio, total_negocios, farmacias, consultorios,
       ROUND(100*(0.40*n_demanda + 0.35*n_poca_comp + 0.25*n_mercado), 1) AS indice_oportunidad
FROM norm
ORDER BY lugar
LIMIT 15;

-- ---------------------------------------------------------------------
-- HALLAZGO 5. Ritmo de apertura de farmacias (¿el mercado se está llenando?)
-- Técnica: análisis temporal por año de alta (cohortes)
-- (Revisa el formato de fecha_alta; aquí se asume que empieza con AAAA)
-- ---------------------------------------------------------------------
SELECT entidad, municipio,
       COUNT(*)                                                         AS farmacias,
       COUNT(*) FILTER (WHERE LEFT(fecha_alta,4) >= '2020')             AS altas_desde_2020,
       ROUND(100.0 * COUNT(*) FILTER (WHERE LEFT(fecha_alta,4) >= '2020')
             / COUNT(*), 1)                                             AS pct_recientes
FROM denue_inegi_oficial
WHERE codigo_act IN (464111, 464112)
GROUP BY entidad, municipio
HAVING COUNT(*) >= 20
ORDER BY pct_recientes DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- HALLAZGO 6. Costo de reabastecimiento: gasolina por estado (tabla 2)
-- Técnica: unión de tablas (JOIN) + promedio de los últimos 12 meses
-- ---------------------------------------------------------------------
WITH gas AS (
    SELECT cve_ent, ROUND(AVG(precio)::numeric, 2) AS gasolina_promedio_12m
    FROM precio_gasolina_estado
    WHERE fecha >= (SELECT MAX(fecha) FROM precio_gasolina_estado) - INTERVAL '12 months'
    GROUP BY cve_ent
)
SELECT m.entidad, m.municipio, m.farmacias, m.consultorios, g.gasolina_promedio_12m,
       ROUND(g.gasolina_promedio_12m - AVG(g.gasolina_promedio_12m) OVER(), 2) AS dif_vs_promedio
FROM mv_municipio_salud m
JOIN gas g ON g.cve_ent = m.cve_ent
WHERE m.total_negocios >= 2000
ORDER BY g.gasolina_promedio_12m;

-- ---------------------------------------------------------------------
-- HALLAZGO 7. Riesgo según noticias (tabla 3)
-- Técnica: agregación de sentimiento por lugar y sector
-- ---------------------------------------------------------------------
SELECT g.cve_ent, g.cve_mun,
       COUNT(DISTINCT n.id)                    AS noticias,
       ROUND(AVG(n.sentimiento)::numeric, 2)   AS sentimiento_promedio,
       COUNT(*) FILTER (WHERE n.sentimiento < 0) AS noticias_negativas
FROM noticia n
JOIN noticia_geo   g ON g.noticia_id = n.id
JOIN noticia_scian s ON s.noticia_id = n.id
WHERE (s.codigo_scian::text LIKE '46%' OR s.codigo_scian::text LIKE '62%')   -- comercio y salud
  AND n.fecha >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY g.cve_ent, g.cve_mun
ORDER BY sentimiento_promedio ASC;
