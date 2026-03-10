# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [Unreleased — 2026-03-10] — Migración LiveView + detección de resultados parciales

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
    de respuesta del core (`%{status: :success}` y `%{estado: :completo}`)

- `assets/js/app.js` — Hook `DropZone` para drag & drop. Solo maneja feedback
  visual — deja que LiveView procese el evento `drop` de forma nativa.

- `core_adapter.ex` — `enrich_result/2`: detecta resultados parciales que el
  core reporta como `:success` pero que contienen líneas/registros inválidos.
  Para CSV compara `valid_records` vs total de líneas del archivo; para JSON
  detecta métricas en cero con archivo no vacío. Aplicado en
  `process_file_single/1` y `process_sequential/1`.

### Cambiado

- `execution_html.ex` — añadidas funciones de presentación: `format_date/1`,
  `format_time/1`, `format_datetime/1`, `mode_badge_color/1`,
  `mode_display_name/1`, `extract_benchmark_data/1`. Movidas desde
  `ExecutionController` para que los templates las resuelvan en su módulo propio.

- `execution_html.ex` — `parse_execution_files/1` detecta modo `benchmark` y
  devuelve el reporte completo como un único item, en lugar de buscar secciones
  `[archivo]` que no existen en ese formato. El badge distingue tres estados:
  Éxito / Parcial (amarillo) / Error (rojo).

- `execution_html.ex` — `get_execution_summary/1` maneja modo `benchmark`
  correctamente usando conteo de archivos. Cuenta `• Estado: parcial` como
  no-exitoso en el resumen.

- `execution_html.ex` — `extract_benchmark_data/1` con patrones regex que
  reconocen prefijos emoji (`📈 Secuencial:`, `⚡ Paralelo:`).

- `execution_html.ex` — `has_error?` en `index.html.heex` ahora usa
  `execution.status != "success"` en lugar de parsear el texto del reporte
  (que siempre contenía `"❌ Errores: 0"` aunque todo fuera exitoso).

- `report_builder.ex` — `format_file_result/1` para CSV/JSON/LOG acepta
  `:partial` además de `:success` y escribe `• Estado: parcial` en el reporte.
  Añadido `status_label/1` para centralizar el texto del estado.

- `index.html.heex` — rediseño UX completo: tarjetas de estadísticas con
  gradiente, filtros con estado activo por color de modo, filtros de fecha
  (Hoy / Esta semana) con estado activo subrayado, badges con heroicons,
  acciones de fila con hover coloreado, estado vacío con mensaje específico
  por filtro activo. Botón "Historial" en header de `ProcessingLive`.

- `show_with_styles.html.heex` — rediseño UX completo: eliminado
  `variant="primary"` inválido, reemplazados componentes DaisyUI por Tailwind
  puro (`themes: false`), `<details>/<summary>` nativo con `group-open:rotate-90`
  en lugar de `collapse` DaisyUI, gráfica de benchmark con **Chart.js 4.4**
  (barras verticales, tooltip en ms, adaptación a tema oscuro leyendo
  `document.documentElement.dataset.theme`), `max-h-64 overflow-y-auto` en
  bloques `<pre>`.

- `processing_live.ex` — `finalize_execution/1` distingue tres estados de BD:
  `"success"` / `"partial"` / `"error"`. `:partial` se muestra en amarillo
  con `⚠️ parcial` durante el procesamiento en tiempo real.

- `config/config.exs` — registrado MIME type `text/plain` para `.log`.

### Corregido

- Benchmark no guardaba en BD — `file_states` en modo benchmark era un mapa sin
  nombres reales. `start_processing/1` ahora guarda `filenames` como assign
  separado; `finalize_benchmark/2` lo lee directamente.

- Estado "Parcial" incorrecto en ejecuciones exitosas — `finalize_execution/1`
  solo reconocía `%{status: :success}`. Corregido con `result_success?/1` que
  también reconoce `%{estado: :completo}`.

- Todas las ejecuciones marcadas como "Parcial" en el historial — `has_error?`
  detectaba `"❌"` en el texto del reporte, pero todos los reportes incluyen
  `"❌ Errores: 0"` aunque no haya errores. Corregido usando `execution.status`.

- Archivos corruptos marcados como "Éxito" — el core filtra líneas inválidas
  silenciosamente y retorna `:ok`. Corregido con `enrich_result/2` en
  `CoreAdapter` que detecta la discrepancia post-proceso sin modificar el core.

- Gráfica benchmark no aparecía — regex en `extract_benchmark_data/1` no
  coincidía con el formato emoji del reporte (`📈 Secuencial:` vs `Secuencial:`).

- "No se encontraron resultados" en modo benchmark — `parse_execution_files/1`
  buscaba secciones `[archivo]` inexistentes en el formato benchmark.

- Conteo incorrecto en resumen de ejecución (mostraba "1 de 7" en lugar de
  "2 de 7" archivos con error) — `get_execution_summary/1` buscaba
  `✅ Exitosos:` que no existe en todos los formatos de reporte.

### Pendiente

- `ExecutionLive.Index` — historial con filtros reactivos y paginación en tiempo real
- `ExecutionLive.Show` — detalle de ejecución en LiveView con collapses interactivos
- Modal de confirmación para eliminar ejecuciones
- Tests

---

## [0.3.0] — 2026-03-10 — Refactorización y limpieza

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
  `list_executions_filtered/1` con filtros encadenados.

- `execution_controller.ex` — eliminadas 12 funciones de presentación.

- `router.ex` — rutas explícitas, orden corregido (`delete_all` antes de `/:id`).

### Eliminado

- `show.html.heex`, `new.html.heex`, `edit.html.heex`, `execution_form.html.heex`
- `CoreAdapter.extract_benchmark_summary/1`
- Datos hardcodeados del benchmark

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