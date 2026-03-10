# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [Unreleased — 2026-03-10]

### Añadido

- `lib/file_processor/execution_helpers.ex` — módulo centralizado con todas
  las funciones de presentación: formateo de fechas, íconos por tipo de archivo,
  badges de modo, extracción de métricas y datos de benchmark. Sin dependencias
  de Phoenix, testeable de forma aislada.

- `lib/file_processor/report_builder.ex` — módulo para construcción de reportes
  de texto por modo de procesamiento (`build_sequential/2`, `build_parallel/2`,
  `build_benchmark/2`). Extraído de `ProcessingController`.

### Cambiado

- `core_adapter.ex` — `process_sequential/1` ahora usa `ProcesadorArchivos.process_file/1`
  (parser directo) en lugar de `procesar_con_manejo_errores/2`. Corrige que el modo
  secuencial no calculaba ventas totales ni productos únicos en archivos CSV.
  Añadida limpieza automática de `output/` tras cada ejecución para que el directorio
  permanezca vacío entre procesados — los reportes descargables se sirven desde la BD.

- `executions.ex` — `get_statistics/0` reemplaza 4 queries separadas por 1 sola
  con `group_by`. Añadida `list_executions_filtered/1` con filtros encadenados por
  modo y rango de fechas, preparada para LiveView.

- `execution_controller.ex` — eliminadas 12 funciones de presentación que no son
  responsabilidad del controller. Filtrado actualizado para usar
  `list_executions_filtered/1`.

- `execution_html.ex` — eliminadas funciones duplicadas respecto al controller
  (`file_icon/1`, `extract_file_section/2`, `extract_metrics/2`). Delega a
  `ExecutionHelpers`.

- `processing_controller.ex` — construcción de reportes movida a `ReportBuilder`.
  Eliminadas dos funciones de cleanup duplicadas con lógica frágil. El status de
  la ejecución ahora se determina leyendo `:status`/`:estado` del core directamente,

- `index.html.heex` — reemplazadas llamadas directas al controller por
  `ExecutionHelpers`. Detección de errores basada en `execution.status` de la BD
  en lugar de parsear el texto del reporte.

- `show_with_styles.html.heex` — fusionado con `show.html.heex`. Integrado canvas
  de Chart.js para visualización del benchmark. Niveles de log con loop en lugar
  de 5 bloques idénticos repetidos.

- `router.ex` — reemplazado `resources "/executions"` por rutas explícitas,
  eliminando rutas generadas automáticamente que no se usan (`new`, `edit`,
  `update`, `create` de executions). Corregido orden de rutas para evitar que
  Phoenix interprete `"delete_all"` como un `:id`.

- `README.md` — reemplazado el contenido genérico de Phoenix por documentación
  real del proyecto: características, requisitos, estructura y tecnologías.

### Eliminado

- `execution_html/show.html.heex` — fusionado en `show_with_styles.html.heex`
- `execution_html/new.html.heex` — ruta eliminada del router
- `execution_html/edit.html.heex` — ruta eliminada del router
- `execution_html/execution_form.html.heex` — sin acción que lo use
- `CoreAdapter.extract_benchmark_summary/1` — sin usages tras la refactorización
- Datos hardcodeados del benchmark en `CoreAdapter` (métricas inventadas por tipo
  de archivo)

### Pendiente (próxima iteración)

- Migración de controllers a LiveView
- Refactorización del core (`output/`, naming inconsistente, bug en `Coordinator`)

---

## [0.2.0] — 2026-xx-xx

### Añadido

- Interfaz web con Phoenix Framework
- Persistencia de ejecuciones en PostgreSQL con Ecto
- Historial con filtros por modo y fecha
- Descarga de reportes en formato `.txt`
- Soporte para subida de múltiples archivos simultáneos

---

## [0.1.0] — 2026-xx-xx

### Añadido

- Core de procesamiento en Elixir puro (`ProcesadorArchivos`)
- Parsers para CSV, JSON y LOG
- Tres modos: secuencial, paralelo y benchmark
- Interfaz CLI con `OptionParser`
- Patrón Coordinator/Worker para procesamiento paralelo