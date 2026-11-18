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

### Códigos SCIAN utilizados

| Código | Actividad |
|---|---|
| 464111 | Farmacias sin minisúper |
| 464112 | Farmacias con minisúper |
| 462112 | Minisúper (tiendas de conveniencia) |
| 6211xx | Consultorios médicos |
| 6215xx | Laboratorios médicos y de diagnóstico |
| 622xxx | Hospitales |

## Indicadores del análisis

- **Saturación:** farmacias por cada 1,000 negocios en el municipio.
- **Demanda de salud:** consultorios, laboratorios y hospitales por cada farmacia.
- **Tipo de competencia:** porcentaje de farmacias pequeñas (0 a 5 empleados).
- **Ritmo de aperturas:** porcentaje de farmacias dadas de alta en años recientes.
- **Costo de abasto:** precio promedio de la gasolina en el estado durante los últimos 12 meses.
- **Riesgo:** sentimiento promedio de las noticias de comercio y salud del municipio.

## Estructura del informe

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
