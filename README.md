# FileProcessor

Aplicación Phoenix para procesar archivos de datos en múltiples formatos (CSV, JSON, LOG) con soporte para procesamiento secuencial, paralelo y benchmark comparativo.

## Características

- **Tres modos de procesamiento**
  - `Secuencial` — procesa archivos uno por uno
  - `Paralelo` — procesa archivos simultáneamente con el patrón Coordinator/Worker
  - `Benchmark` — compara el rendimiento secuencial vs paralelo con gráfica Chart.js
- **Formatos soportados** — CSV (datos de ventas), JSON (usuarios y sesiones), LOG (niveles de sistema)
- **Interfaz reactiva con LiveView** — feedback en tiempo real, drag & drop, barras de progreso, filtros sin recarga, modal de confirmación
- **Detección de resultados parciales** — archivos con datos corruptos se marcan como `partial` en lugar de `success`
- **Historial de ejecuciones** — almacenado en PostgreSQL con filtros por modo y fecha
- **Descarga de reportes** — exporta el resultado de cada ejecución como `.txt`
- **Tema claro/oscuro** — soporte completo en todos los componentes

## Requisitos

- Elixir 1.14+
- Erlang/OTP 25+
- PostgreSQL 14+

## Configuración

```bash
# Instalar dependencias y crear la base de datos
mix setup

# Iniciar el servidor
mix phx.server
```

Visita [`localhost:4000`](http://localhost:4000) desde el navegador. La ruta raíz redirige automáticamente a `/processing`.

## Uso

1. Ve a `/processing`, arrastra archivos o usa el botón de selección
2. Elige el modo de procesamiento (Secuencial, Paralelo o Benchmark)
3. Pulsa **Procesar archivos** — el progreso se actualiza en tiempo real por archivo
4. Al finalizar, el resultado se guarda automáticamente en el historial (`/executions`)
5. Desde el historial puedes filtrar por modo o fecha, ver el reporte detallado, descargarlo como `.txt` o eliminar ejecuciones con confirmación modal

## Estructura del proyecto

```
lib/
├── file_processor/                       # Contexto y lógica de negocio
│   ├── core_adapter.ex                   # Puente entre Phoenix y el core Elixir puro
│   │                                     # Incluye enrich_result/2 para detección de parciales
│   ├── execution_helpers.ex              # Helpers de presentación (fechas, íconos, métricas)
│   ├── executions.ex                     # Contexto Ecto — queries, filtros y estadísticas
│   ├── executions/
│   │   └── execution.ex                  # Schema Ecto
│   ├── report_builder.ex                 # Construcción de reportes por modo
│   └── repo.ex
│
├── file_processor/                       # Core de procesamiento (Elixir puro, sin Phoenix)
│   ├── coordinador.ex                    # Patrón Coordinator/Worker
│   ├── worker.ex
│   ├── procesador_archivos.ex            # Orquestador principal
│   ├── csv_parser.ex
│   ├── json_parser.ex
│   ├── log_parser.ex
│   └── procesar_con_manejo_errores.ex
│
└── file_processor_web/                   # Capa web Phoenix
    ├── live/
    │   ├── processing_live.ex            # LiveView — subida y procesamiento en tiempo real
    │   ├── execution_live.ex             # LiveView — historial con filtros reactivos y modal
    │   ├── execution_live.html.heex
    │   ├── execution_show_live.ex        # LiveView — reporte detallado por archivo
    │   └── execution_show_live.html.heex
    ├── controllers/
    │   ├── execution_controller.ex       # Solo download, delete y delete_all
    │   ├── execution_html.ex             # Helpers de parseo y presentación para LiveViews
    │   └── page_controller.ex            # Redirige / → /processing
    ├── router.ex
    └── endpoint.ex

assets/
└── js/
    └── app.js                            # Hook DropZone (drag & drop) + renderBenchmarkChart

test/
├── file_processor/
│   ├── executions_test.exs               # CRUD, filtros y estadísticas
│   └── report_builder_test.exs           # Formato de reportes por modo y tipo de archivo
├── file_processor_web/
│   ├── execution_html_test.exs           # Helpers de parseo y presentación
│   ├── controllers/
│   │   ├── execution_controller_test.exs # download, delete, delete_all
│   │   └── page_controller_test.exs
│   └── live/
│       ├── execution_live_test.exs       # Filtros reactivos y modal de confirmación
│       └── execution_show_live_test.exs  # Reporte, métricas y navegación
└── support/
    └── fixtures/
        └── executions_fixtures.ex
```

## Tests

```bash
mix test
```

## Estados de ejecución

| Estado | Descripción |
|--------|-------------|
| `success` | Todos los archivos procesados correctamente |
| `partial` | Uno o más archivos tienen líneas o registros inválidos |
| `error` | Todos los archivos fallaron |

## Tecnologías

- [Phoenix Framework](https://www.phoenixframework.org/) 1.8
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) — interfaz reactiva en tiempo real
- [Ecto](https://hexdocs.pm/ecto) + PostgreSQL
- [Tailwind CSS](https://tailwindcss.com/) v4 + [DaisyUI](https://daisyui.com/)
- [Chart.js](https://www.chartjs.org/) 4.4 — gráfico comparativo de benchmark
- [Heroicons](https://heroicons.com/) — iconografía