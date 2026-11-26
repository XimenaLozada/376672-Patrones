# 376672-Patrones

Proyecto de **Inteligencia de Negocios**: informe de consultoría de datos para decidir dónde abrir la próxima sucursal de una cadena de farmacias.

## Cliente y objetivo de negocio

| | |
|---|---|
| **Cliente** | Dirección de Expansión de una cadena regional de farmacias |
| **Audiencia** | Director de expansión, comité directivo, operaciones y logística, finanzas |
| **Objetivo** | Elegir con datos el municipio con mayor oportunidad para la próxima sucursal y una alternativa |

**Pregunta principal de negocio:**
¿En qué municipio existe la mayor oportunidad para abrir la próxima sucursal de la cadena, considerando la cantidad de servicios de salud que generan recetas, el número y tamaño de las farmacias que ya operan ahí y el costo de abastecer la sucursal?

## Fuentes de datos

Base de datos PostgreSQL (consultada con DBeaver).

| Tabla | Origen | Uso en el análisis |
|---|---|---|
| `denue_inegi_oficial` | DENUE, INEGI | Contar farmacias, consultorios, laboratorios, hospitales y tiendas de conveniencia por municipio; tamaño (`per_ocu`) y fecha de alta de cada negocio |
| `cat_municipio`, `cat_scian` | Catálogos geográficos y de actividad económica | Validar claves de municipio y códigos de giro |
| `precio_gasolina_estado` | Precios de gasolina por estado | Estimar el costo de reabastecer una sucursal en cada estado |
| `noticia`, `noticia_geo`, `noticia_scian` | Noticias con lugar, sector y sentimiento | Detectar riesgos (inseguridad, cierres, conflictos) en los municipios candidatos |
| `diagnostico_calidad` | Problemas de calidad documentados | Explicar los límites del análisis |

### Por qué estas fuentes

Cada fuente responde una parte distinta de la pregunta de negocio, y todas se unen por la clave de estado y municipio:

- **DENUE:** dónde está la demanda (consultorios, laboratorios y hospitales que generan recetas) y dónde está la competencia (farmacias y tiendas de conveniencia).
- **Gasolina por estado:** cuánto cuesta reabastecer la sucursal una vez abierta.
- **Noticias:** contexto que los números no muestran, como inseguridad, cierres de comercios o conflictos locales.

### Periodo y cobertura

| Aspecto | Detalle |
|---|---|
| Periodo | DENUE: corte a la fecha de su publicación; aperturas revisadas con `fecha_alta`. Gasolina y noticias: últimos 12 meses disponibles en la base |
| Cobertura geográfica | Nacional, 32 entidades federativas; unidad de análisis: municipio (la gasolina sólo existe por estado) |
| Registros | DENUE con más de 5 millones de establecimientos |
| Fecha de consulta | Noviembre de 2026 |
| Restricciones | El DENUE no incluye ventas en línea ni comercio informal; las tablas se actualizan en fechas distintas; las noticias cubren más las ciudades grandes que los municipios pequeños |

### Códigos SCIAN utilizados

| Código | Actividad |
|---|---|
| 464111 | Farmacias sin minisúper |
| 464112 | Farmacias con minisúper |
| 462112 | Minisúper (tiendas de conveniencia) |
| 6211xx | Consultorios médicos |
| 6215xx | Laboratorios médicos y de diagnóstico |
| 622xxx | Hospitales |

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| `README.md` | Descripción del proyecto |
| `sql/consultas_farmacias.sql` | Consultas de calidad de datos, vista base por municipio y una consulta por hallazgo |
| `sql/resultados_para_informe.sql` | Consultas resumidas que generan todas las cifras del informe (totales, ranking con todos los indicadores, gasolina, noticias y calidad) |

## Cómo reproducir el análisis

1. Abrir la base de datos PostgreSQL en DBeaver.
2. Ejecutar la consulta 0 de `sql/consultas_farmacias.sql` para revisar los nombres de columna de las tablas fuera del DENUE y ajustarlos si es necesario.
3. Ejecutar las consultas 1a a 1c (calidad de datos).
4. Ejecutar la consulta 2, que crea la vista materializada `mv_municipio_salud`. Es la más pesada, porque recorre todo el DENUE, y sólo se ejecuta una vez.
5. Ejecutar las consultas de los hallazgos 1 a 7.

## Técnicas utilizadas

| Técnica | Hallazgo |
|---|---|
| Agregación por grupo y tasa normalizada | 1. Farmacias por cada 1,000 negocios |
| Razón entre complementos y competidores | 2. Servicios de salud por farmacia |
| Segmentación por categoría | 3. Porcentaje de farmacias pequeñas |
| Normalización min-max, índice ponderado (40/35/25) y `RANK()` | 4. Índice de oportunidad y ranking |
| Análisis temporal por cohortes de alta | 5. Ritmo de aperturas desde 2020 |
| Integración de fuentes (`JOIN`) y promedio de 12 meses | 6. Costo de gasolina por estado |
| Agregación de sentimiento por lugar y sector | 7. Riesgo según noticias |

## Calidad de datos

- `raz_social` vacía en gran parte del DENUE: no se puede identificar con certeza qué farmacias pertenecen a una cadena; se usa `per_ocu` como aproximación.
- Establecimientos con nombre genérico ("SIN NOMBRE"): se conservan en los conteos, pero no sirven para identificar marcas.
- Posibles claves `clee` duplicadas: se revisan con la consulta 1c.
- La gasolina sólo está disponible por estado, no por municipio.

## Indicadores del análisis

- **Saturación:** farmacias por cada 1,000 negocios en el municipio.
- **Demanda de salud:** consultorios, laboratorios y hospitales por cada farmacia.
- **Tipo de competencia:** porcentaje de farmacias pequeñas (0 a 5 empleados).
- **Ritmo de aperturas:** porcentaje de farmacias dadas de alta en años recientes.
- **Costo de abasto:** precio promedio de la gasolina en el estado durante los últimos 12 meses.
- **Riesgo:** sentimiento promedio de las noticias de comercio y salud del municipio.

## Estructura del informe

Avance: las 11 secciones están redactadas. Faltan los resultados numéricos (marcados como [X] en el informe): al cierre del informe no fue posible conectarse al servidor de la base de datos desde fuera de la red de la universidad. Cuando se recupere el acceso, se ejecutará `sql/resultados_para_informe.sql` para completarlos.

1. Resumen ejecutivo
2. Contexto del cliente y objetivo de negocio
3. Planteamiento del problema
4. Fuentes de información y datos utilizados
5. Metodología y técnicas de análisis
6. Hallazgos principales
7. Calidad y confiabilidad de los datos
8. Recomendación estratégica
9. Conclusiones
10. Referencias
11. Anexos técnicos

## Autora

Ximena Lozada (376672)
