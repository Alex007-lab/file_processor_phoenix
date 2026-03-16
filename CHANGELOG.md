# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [0.7.0] — 2026-03-15 — Tests
> 👤 Alex Gomez

### Añadido

- `test/file_processor/report_builder_test.exs` — tests para `build_sequential/2`,
  `build_parallel/2` y `build_benchmark/2`: formato por tipo de archivo (CSV,
  JSON, LOG), conteo de exitosos/parciales/errores, tiempos, estado parcial,
  ganador del benchmark.

- `test/file_processor_web/execution_html_test.exs` — tests para `file_icon/1`,
  `format_datetime/1`, `format_date/1`, `format_time/1`, `extract_metrics/2`,
  `parse_execution_files/1` y `extract_benchmark_data/1`.

- `test/file_processor_web/live/execution_live_test.exs` — tests de LiveView
  para el historial: mount, filtros reactivos por modo (sequential/parallel/
  benchmark/todos), modal de confirmación (abrir, cancelar con botón,
  confirmar eliminación individual y total).

- `test/file_processor_web/live/execution_show_live_test.exs` — tests de
  LiveView para el reporte: mount con cada tipo de archivo, tarjetas de resumen,
  métricas CSV/JSON/LOG, sección benchmark, badge Parcial/Completado,
  navegación (volver, descargar), 404 para id inexistente.

### Cambiado

- `test/support/fixtures/executions_fixtures.ex` — `"some mode"` reemplazado
  por `"sequential"`. Añadidos fixtures `execution_fixture_parallel/1`,
  `execution_fixture_benchmark/1` y `execution_fixture_partial/1`.

- `test/file_processor/executions_test.exs` — añadidos tests para
  `list_executions_filtered/1` (por modo, por fecha, combinado, sin resultados,
  filtros desconocidos) y `get_statistics/0` (ceros, conteo por modo, promedio
  de tiempo).

- `test/file_processor_web/controllers/execution_controller_test.exs` —
  reescrito completamente. Eliminados tests de rutas inexistentes (`new`,
  `create`, `edit`, `update`). Cubre solo `download`, `delete` y `delete_all`.
  Corregido `get_flash/2` deprecado por `Phoenix.Flash.get/2`.

- `test/file_processor_web/controllers/page_controller_test.exs` — corregido
  para verificar redirección a `/processing` en lugar de texto genérico de
  Phoenix por defecto.

### Corregido

- Selector ambiguo `[phx-click='cancel_modal']` en `execution_live_test.exs`
  — el modal tiene backdrop y botón con el mismo atributo. Corregido a
  `button[phx-click='cancel_modal']`.

---

## [0.6.0] — 2026-03-15 — Modal de confirmación + rediseño UX reporte + limpieza
> 👤 Alex Gomez

### Añadido

- `execution_live.ex` — modal de confirmación LiveView para eliminar ejecuciones.
  Cuatro nuevos eventos: `confirm_delete`, `confirm_delete_all`, `cancel_modal`,
  `delete`, `delete_all`. El modal muestra contenido distinto para eliminar uno
  vs limpiar todo. Se cierra con `Escape` o click en backdrop. Reemplaza
  `data-confirm` nativo del browser.

### Cambiado

- `execution_live.html.heex` — botones de eliminar migrados de `<.link
  method="delete" data-confirm>` a `phx-click="confirm_delete"`. Modal añadido
  al final del template con backdrop blur, ícono de advertencia, mensaje
  contextual y botones Cancelar / Confirmar.

- `execution_show_live.html.heex` — rediseño UX completo del reporte:
  - Tarjetas de resumen con gradiente y color semántico por modo (azul/verde/
    morado/naranja/esmeralda)
  - Métricas visuales por tipo de archivo: CSV (registros, productos, ventas),
    JSON (usuarios, activos, sesiones), LOG (total + 5 niveles con color
    semántico por severidad)
  - Collapses con `divide-y` y fondo diferenciado al expandir
  - `<pre>` de salida completa con borde de color según estado del archivo

- `execution_controller.ex` — eliminadas acciones `index` y `show` (migradas a
  LiveView). Solo conserva `download`, `delete` y `delete_all`.

- `execution_html.ex` — eliminadas funciones duplicadas del controller. Solo
  conserva las que usan los LiveViews: `parse_execution_files/1`,
  `extract_file_section/1`, `extract_metrics/2`, `get_execution_summary/1`,
  `extract_benchmark_data/1`, `file_icon/1`, helpers de formato y modo.

### Corregido

- Comentarios `<%#` migrados a `<%!-- --%>` (sintaxis deprecated en HEEx 1.7+).

### Eliminado

- `controllers/execution_html/show_with_styles.html.heex` — huérfano tras
  migración a `ExecutionShowLive`
- `controllers/execution_html/index.html.heex` — huérfano tras migración a
  `ExecutionLive`
- `controllers/processing_controller.ex` — reemplazado por `ProcessingLive`
- `controllers/processing_html.ex` — módulo del controller eliminado
- `controllers/processing_html/new.html.heex` — template del controller eliminado

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

- `execution_html.ex` — añadidas funciones de presentación, `parse_execution_files/1`
  detecta modo benchmark, `get_execution_summary/1` usa `Regex.scan`,
  `extract_benchmark_data/1` reconoce prefijos emoji.

- `report_builder.ex` — `format_file_result/1` acepta `:partial` y escribe
  `• Estado: parcial`. Añadido `status_label/1`. Eliminada cláusula `_`
  inalcanzable detectada por Dialyzer.

- `processing_live.ex` — `finalize_execution/1` distingue tres estados:
  `"success"` / `"partial"` / `"error"`.

- `index.html.heex` — rediseño UX completo con gradientes, filtros reactivos,
  badges con heroicons. Botón "Historial" en header de `ProcessingLive`.

- `show_with_styles.html.heex` — Tailwind puro, Chart.js 4.4, dark mode.

- `config/config.exs` — registrado MIME type `text/plain` para `.log`.

### Corregido

- Benchmark no guardaba en BD, archivos corruptos marcados "Éxito",
  "No se encontraron resultados" en benchmark, estado "Parcial" incorrecto
  en ejecuciones exitosas.

---

## [0.3.0] — 2026-03-10 — Refactorización y limpieza
> 👤 Alex Gomez

### Añadido

- `lib/file_processor/execution_helpers.ex` — módulo centralizado con funciones
  de presentación sin dependencias de Phoenix.

- `lib/file_processor/report_builder.ex` — construcción de reportes por modo
  (`build_sequential/2`, `build_parallel/2`, `build_benchmark/2`).

### Cambiado

- `core_adapter.ex` — `process_sequential/1` usa `ProcesadorArchivos.process_file/1`.
  Limpieza automática de `output/`.

- `executions.ex` — `get_statistics/0` con una sola query `group_by`.
  `list_executions_filtered/1` con filtros encadenados.

- `execution_controller.ex` — eliminadas 12 funciones de presentación.

- `router.ex` — rutas explícitas, orden corregido.

### Eliminado

- `show.html.heex`, `new.html.heex`, `edit.html.heex`, `execution_form.html.heex`
- `CoreAdapter.extract_benchmark_summary/1`
- Datos hardcodeados del benchmark

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