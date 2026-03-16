# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [Unreleased — 2026-03-15] — Correcciones post-integración
> 👤 Alex Gomez

### Corregido

- `execution_show_live.ex` — doble llamada a `parse_execution_files/1`: se
  llamaba en `mount` y de nuevo dentro de `get_execution_summary`. Corregido
  parseando una sola vez en `mount` y pasando el resultado a `build_summary/2`.

- `execution_html.ex` — `has_error?` ahora usa `execution.status != "success"`
  en lugar de parsear el texto del reporte, que siempre contenía
  `"❌ Errores: 0"` aunque no hubiera errores.

- `execution_html.ex` — `get_execution_summary/1` reemplaza búsqueda de
  `✅ Exitosos:` por `Regex.scan` sobre `• Estado: éxito` / `• Estado: error`
  / `• Estado: parcial`, compatible con todos los formatos de reporte.

- `execution_html.ex` — `extract_benchmark_data/1` corregido con patrones regex
  que reconocen prefijos emoji (`📈 Secuencial:`, `⚡ Paralelo:`).

- `report_builder.ex` — eliminada cláusula `_` inalcanzable en `status_label/1`
  detectada por Dialyzer.

---

## [0.5.0] — 2026-03-11 — Migración LiveView: historial y reporte
> 👤 Sharon Anette

### Añadido

- `lib/file_processor_web/live/execution_live.ex` — LiveView para historial de
  ejecuciones. Filtros reactivos por modo (`sequential`, `parallel`, `benchmark`)
  y por fecha (`today`, `week`) mediante `handle_event("filter")` sin recargar.

- `lib/file_processor_web/live/execution_live.html.heex` — template del historial:
  dashboard de estadísticas por modo, filtros con estado activo visual, tabla con
  badge de estado (`success`/`partial`/`error`), acciones por fila.

- `lib/file_processor_web/live/execution_show_live.ex` — LiveView para detalle
  de ejecución con collapses interactivos `<details>/<summary>` por archivo.

- `lib/file_processor_web/live/execution_show_live.html.heex` — template del
  reporte: tarjetas de resumen, gráfica Chart.js con `data-secuencial`/
  `data-paralelo` en el canvas, badge de estado por archivo.

- `assets/js/app.js` — `renderBenchmarkChart` lee `data-*` del canvas en lugar
  de `<script>` inline — compatible con LiveView. Se dispara en
  `DOMContentLoaded` y `phx:page-loading-stop`.

### Cambiado

- `router.ex` — rutas `/executions` y `/executions/:id` migradas de controllers
  a LiveView (`ExecutionLive` y `ExecutionShowLive`). Controllers conservados
  solo para `delete`, `delete_all` y `download`.

- `README.md` — estructura del proyecto actualizada con los nuevos módulos LiveView.

---

## [0.4.0] — 2026-03-10 — ProcessingLive + detección de resultados parciales
> 👤 Alex Gomez

### Añadido

- `lib/file_processor_web/live/processing_live.ex` — LiveView completo para
  procesamiento de archivos. Reemplaza `ProcessingController` como punto de
  entrada principal. Incluye:
  - Subida de archivos con `allow_upload` (`auto_upload: true`, hasta 10 archivos,
    10 MB por archivo, formatos CSV/JSON/LOG)
  - Drag & drop con Hook `DropZone` en `app.js`
  - Feedback en tiempo real por archivo (`:pending → :processing → :success/:partial/:error`)
  - Selector de modo con indicador visual activo (✓) y `aria-pressed`
  - Zona de drop con estado dinámico — cambia al seleccionar archivos
  - Barra de progreso de subida con porcentaje y estado "Listo" al completar
  - Persistencia automática en BD al finalizar con `finalize_execution/1`
  - Medición real de `total_time` con `System.monotonic_time`
  - Orden de archivos preservado usando lista de tuplas en lugar de mapa
  - `result_success?/1` y `result_partial?/1` que manejan los dos formatos
    del core (`%{status: :success}` y `%{estado: :completo}`)

- `assets/js/app.js` — Hook `DropZone` para drag & drop. Solo maneja feedback
  visual — deja que LiveView procese el evento `drop` de forma nativa.

- `core_adapter.ex` — `enrich_result/2`: detecta resultados parciales que el
  core reporta como `:success` pero que contienen líneas/registros inválidos.
  Para CSV compara `valid_records` vs total de líneas del archivo; para JSON
  detecta métricas en cero con archivo no vacío.

### Cambiado

- `execution_html.ex` — añadidas funciones de presentación: `format_date/1`,
  `format_time/1`, `format_datetime/1`, `mode_badge_color/1`,
  `mode_display_name/1`, `extract_benchmark_data/1`. `parse_execution_files/1`
  detecta modo benchmark y devuelve item único con reporte completo.

- `report_builder.ex` — `format_file_result/1` acepta `:partial` además de
  `:success` y escribe `• Estado: parcial`. Añadido `status_label/1`.

- `processing_live.ex` — `finalize_execution/1` distingue tres estados de BD:
  `"success"` / `"partial"` / `"error"`. `:partial` se muestra en amarillo
  con `⚠️ parcial` en tiempo real.

- `index.html.heex` — rediseño UX: tarjetas con gradiente, filtros con estado
  activo por color, filtros de fecha, badges con heroicons, estado vacío
  contextual. Botón "Historial" en header de `ProcessingLive`.

- `show_with_styles.html.heex` — Tailwind puro sin DaisyUI, `<details>/<summary>`
  nativo, gráfica Chart.js 4.4 con soporte dark mode, `max-h-64` en `<pre>`.

- `config/config.exs` — registrado MIME type `text/plain` para `.log`.

### Corregido

- Benchmark no guardaba en BD — `file_states` en modo benchmark no contenía
  nombres reales. `start_processing/1` ahora guarda `filenames` como assign
  separado.

- Archivos corruptos marcados como "Éxito" — el core filtra líneas inválidas
  silenciosamente. Corregido con `enrich_result/2` sin modificar el core.

- "No se encontraron resultados" en modo benchmark — `parse_execution_files/1`
  buscaba secciones `[archivo]` inexistentes en ese formato.

- Estado "Parcial" incorrecto en ejecuciones exitosas — `finalize_execution/1`
  solo reconocía `%{status: :success}`. Corregido con `result_success?/1`.

---

## [0.3.0] — 2026-03-10 — Refactorización y limpieza
> 👤 Alex Gomez

### Añadido

- `lib/file_processor/execution_helpers.ex` — módulo centralizado con funciones
  de presentación: formateo de fechas, íconos, badges de modo, extracción de
  métricas y datos de benchmark. Sin dependencias de Phoenix.

- `lib/file_processor/report_builder.ex` — construcción de reportes por modo
  (`build_sequential/2`, `build_parallel/2`, `build_benchmark/2`).

### Cambiado

- `core_adapter.ex` — `process_sequential/1` usa `ProcesadorArchivos.process_file/1`.
  Corrige cálculo de ventas y productos en CSV. Limpieza automática de `output/`.

- `executions.ex` — `get_statistics/0` con una sola query `group_by`.
  `list_executions_filtered/1` con filtros encadenados por modo y fecha.

- `execution_controller.ex` — eliminadas 12 funciones de presentación.

- `router.ex` — rutas explícitas, orden corregido (`delete_all` antes de `/:id`).

### Eliminado

- `show.html.heex`, `new.html.heex`, `edit.html.heex`, `execution_form.html.heex`
- `CoreAdapter.extract_benchmark_summary/1`
- Datos hardcodeados del benchmark en `CoreAdapter`

---

## [0.2.0] — 2026-02-23 — Interfaz web Phoenix
> 👤 Alex Gomez · 👤 Sharon Anette

### Añadido
> 👤 Alex Gomez

- Interfaz web con Phoenix Framework y Tailwind CSS
- Adaptador `CoreAdapter` para conectar Phoenix con el core Elixir puro
- Historial de ejecuciones con filtros por modo y fecha
- Descarga de reportes en formato `.txt`
- Soporte para subida de múltiples archivos simultáneos
- Gráfica comparativa de benchmark con Chart.js

### Corregido
> 👤 Sharon Anette

- Extracción correcta de resultados en modos secuencial y paralelo
- Manejo de directorio temporal y limpieza para benchmark
- Persistencia de archivos entre ejecuciones
- Descarga de reportes de error en formato ZIP
- Mejoras de diseño en la interfaz

---

## [0.1.0] — 2026-02-13 — Proyecto inicial
> 👤 Alex Gomez

### Añadido

- Proyecto Phoenix inicializado con el core `ProcesadorArchivos` copiado intacto
- Core de procesamiento en Elixir puro: parsers CSV, JSON y LOG
- Tres modos: secuencial, paralelo y benchmark
- Interfaz CLI con `OptionParser`
- Patrón Coordinator/Worker para procesamiento paralelo