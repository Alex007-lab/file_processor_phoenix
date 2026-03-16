# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [0.8.0] — 2026-03-15 — Paginación en tiempo real
> 👤 Alex Gomez

### Añadido

- `Executions.list_executions_paginated/3` — nueva función que recibe filtros,
  página y tamaño de página. Ejecuta un `COUNT` y un `SELECT` con `LIMIT`/
  `OFFSET`. Devuelve `%{entries, page, per_page, total, total_pages}`.

- `ExecutionLive` — tres nuevos eventos: `prev_page`, `next_page` y
  `go_to_page`. Al filtrar siempre resetea a página 1. Al eliminar el último
  registro de una página retrocede automáticamente una página.

- `execution_live.html.heex` — footer de paginación debajo de la tabla:
  muestra "Página X de Y · N ejecuciones", botones Anterior/Siguiente
  deshabilitados en los extremos, y números de página en rango ±2 alrededor
  de la página actual. Solo visible cuando `total_pages > 1`.

- `test/file_processor/executions_test.exs` — 5 tests para
  `list_executions_paginated/3`: primera página, segunda página, sin registros,
  filtros combinados con paginación, orden descendente.

- `test/file_processor_web/live/execution_live_test.exs` — 5 tests de LiveView
  para los controles de paginación: sin controles con ≤10 ejecuciones, controles
  visibles con >10, navegar a siguiente, navegar a anterior, resetear a página 1
  al filtrar.

### Cambiado

- `ExecutionLive` — `build_filters/1` centraliza la construcción de filtros
  para reutilizarla en eventos de filtrado, paginación y eliminación.
  `assign_pagination/2` centraliza la asignación de assigns de paginación
  (`executions`, `page`, `total_pages`, `total_count`).

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
  reescrito completamente. Cubre solo `download`, `delete` y `delete_all`.
  Corregido `get_flash/2` deprecado por `Phoenix.Flash.get/2`.

- `test/file_processor_web/controllers/page_controller_test.exs` — corregido
  para verificar redirección a `/processing`.

### Corregido

- Selector ambiguo `[phx-click='cancel_modal']` corregido a
  `button[phx-click='cancel_modal']`.

---

## [0.6.0] — 2026-03-15 — Modal de confirmación + rediseño UX reporte + limpieza
> 👤 Alex Gomez

### Añadido

- `execution_live.ex` — modal de confirmación LiveView para eliminar ejecuciones.
  Eventos: `confirm_delete`, `confirm_delete_all`, `cancel_modal`, `delete`,
  `delete_all`. Se cierra con `Escape` o click en backdrop. Reemplaza
  `data-confirm` nativo del browser.

### Cambiado

- `execution_live.html.heex` — botones de eliminar migrados a `phx-click`.
  Modal con backdrop blur, ícono de advertencia y botones Cancelar / Confirmar.

- `execution_show_live.html.heex` — rediseño UX: tarjetas con gradiente y color
  semántico por modo, métricas visuales por tipo (CSV/JSON/LOG), collapses con
  `divide-y`, `<pre>` con borde de color según estado.

- `execution_controller.ex` — eliminadas acciones `index` y `show`. Solo
  conserva `download`, `delete` y `delete_all`.

- `execution_html.ex` — eliminadas funciones duplicadas del controller.

### Corregido

- Comentarios `<%#` migrados a `<%!-- --%>`.

### Eliminado

- `show_with_styles.html.heex`, `index.html.heex` (controllers)
- `processing_controller.ex`, `processing_html.ex`, `processing_html/new.html.heex`

---

## [0.5.0] — 2026-03-11 — Migración LiveView: historial y reporte
> 👤 Sharon Anette

### Añadido

- `execution_live.ex` + `execution_live.html.heex` — LiveView para historial
  con filtros reactivos por modo y fecha.

- `execution_show_live.ex` + `execution_show_live.html.heex` — LiveView para
  detalle de ejecución con collapses y gráfica Chart.js.

- `app.js` — `renderBenchmarkChart` con `data-*` en canvas, compatible con
  LiveView.

### Cambiado

- `router.ex` — `/executions` y `/executions/:id` migradas a LiveView.
- `README.md` — estructura actualizada.

---

## [0.4.0] — 2026-03-10 — ProcessingLive + detección de resultados parciales
> 👤 Alex Gomez

### Añadido

- `processing_live.ex` — LiveView completo para procesamiento: subida, drag &
  drop, feedback en tiempo real, tres estados (`:success`/`:partial`/`:error`),
  persistencia en BD.

- `core_adapter.ex` — `enrich_result/2`: detecta archivos parcialmente corruptos
  sin modificar el core.

### Cambiado

- `execution_html.ex`, `report_builder.ex`, `processing_live.ex` — soporte para
  estado `partial` en todo el pipeline.

- `index.html.heex`, `show_with_styles.html.heex` — rediseño UX con Tailwind
  puro y Chart.js 4.4.

- `config/config.exs` — MIME type `text/plain` para `.log`.

### Corregido

- Benchmark no guardaba en BD, archivos corruptos marcados "Éxito", gráfica sin
  datos, estado "Parcial" incorrecto en ejecuciones exitosas.

---

## [0.3.0] — 2026-03-10 — Refactorización y limpieza
> 👤 Alex Gomez

### Añadido

- `execution_helpers.ex` — helpers de presentación sin dependencias de Phoenix.
- `report_builder.ex` — construcción de reportes por modo.

### Cambiado

- `core_adapter.ex`, `executions.ex`, `execution_controller.ex`, `router.ex` —
  separación de responsabilidades, queries optimizadas, rutas explícitas.

### Eliminado

- Templates huérfanos (`show.html.heex`, `new.html.heex`, `edit.html.heex`,
  `execution_form.html.heex`), datos hardcodeados del benchmark.

---

## [0.2.0] — 2026-02-23 — Interfaz web Phoenix
> 👤 Alex Gomez · 👤 Sharon Anette

### Añadido
> 👤 Alex Gomez

- Interfaz web con Phoenix Framework y Tailwind CSS, `CoreAdapter`, historial
  con filtros, descarga de reportes, gráfica de benchmark con Chart.js.

### Corregido
> 👤 Sharon Anette

- Resultados secuencial/paralelo, directorio temporal benchmark, persistencia
  de archivos, descarga en ZIP, mejoras de diseño.

---

## [0.1.0] — 2026-02-13 — Proyecto inicial
> 👤 Alex Gomez

### Añadido

- Proyecto Phoenix con core `ProcesadorArchivos` intacto: parsers CSV/JSON/LOG,
  modos secuencial/paralelo/benchmark, CLI con `OptionParser`, patrón
  Coordinator/Worker.