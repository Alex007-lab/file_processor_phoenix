# FileProcessor

Aplicación Phoenix para procesar archivos de datos en múltiples formatos (CSV, JSON, LOG) con soporte para procesamiento secuencial, paralelo y benchmark comparativo.

## Características

- **Tres modos de procesamiento**
  - `Secuencial` — procesa archivos uno por uno
  - `Paralelo` — procesa archivos simultáneamente con el patrón Coordinator/Worker
  - `Benchmark` — compara el rendimiento secuencial vs paralelo con gráfica Chart.js
- **Formatos soportados** — CSV (datos de ventas), JSON (usuarios y sesiones), LOG (niveles de sistema)
- **Interfaz reactiva con LiveView** — feedback en tiempo real durante el procesamiento, drag & drop, barras de progreso de subida
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
3. Pulsa **Procesar archivos** — el progreso se actualiza en tiempo real
4. Al finalizar, el resultado se guarda en el historial (`/executions`)
5. Desde el historial puedes ver el reporte detallado, descargarlo o eliminar ejecuciones

## Estructura del proyecto

```
lib/
├── file_processor/                   # Contexto y lógica de negocio
│   ├── core_adapter.ex               # Puente entre Phoenix y el core Elixir puro
│   ├── execution_helpers.ex          # Helpers de presentación (fechas, íconos, métricas)
│   ├── executions.ex                 # Contexto Ecto — queries y filtros
│   ├── executions/
│   │   └── execution.ex              # Schema Ecto
│   ├── report_builder.ex             # Construcción de reportes por modo
│   └── repo.ex
│
├── procesador_archivos/              # Core de procesamiento (Elixir puro, sin Phoenix)
│   ├── coordinador.ex                # Patrón Coordinator/Worker
│   ├── worker.ex
│   ├── procesador_archivos.ex        # Orquestador principal
│   ├── csv_parser.ex
│   ├── json_parser.ex
│   ├── log_parser.ex
│   └── procesar_con_manejo_errores.ex
│
└── file_processor_web/               # Capa web Phoenix
    ├── live/
    │   └── processing_live.ex        # LiveView — subida y procesamiento en tiempo real
    ├── controllers/
    │   ├── execution_controller.ex   # Historial y detalle (Phoenix controller)
    │   ├── processing_controller.ex  # Fallback (pendiente migrar a LiveView)
    │   └── execution_html/           # Templates del historial
    │       ├── index.html.heex
    │       └── show_with_styles.html.heex
    ├── router.ex
    └── endpoint.ex

assets/
└── js/
    └── app.js                        # Hook DropZone para drag & drop en LiveView
```

## Tests

```bash
mix test
```

## Tecnologías

- [Phoenix Framework](https://www.phoenixframework.org/) 1.8
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) — interfaz reactiva en tiempo real
- [Ecto](https://hexdocs.pm/ecto) + PostgreSQL
- [Tailwind CSS](https://tailwindcss.com/) v4 + [DaisyUI](https://daisyui.com/)
- [Chart.js](https://www.chartjs.org/) 4.4 — gráfico comparativo de benchmark
- [Heroicons](https://heroicons.com/) — iconografía