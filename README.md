# FileProcessor

Aplicación Phoenix para procesar archivos de datos en múltiples formatos (CSV, JSON, LOG) con soporte para procesamiento secuencial, paralelo y benchmark comparativo.

## Características

- **Tres modos de procesamiento**
  - `Secuencial` — procesa archivos uno por uno
  - `Paralelo` — procesa archivos simultáneamente con el patrón Coordinator/Worker
  - `Benchmark` — compara el rendimiento secuencial vs paralelo
- **Formatos soportados** — CSV (datos de ventas), JSON (usuarios y sesiones), LOG (niveles de sistema)
- **Historial de ejecuciones** — almacenado en PostgreSQL con filtros por modo y fecha
- **Descarga de reportes** — exporta el resultado de cada ejecución como `.txt`

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

1. Ve a `/processing`, selecciona uno o más archivos y elige el modo
2. El resultado se guarda automáticamente en el historial (`/executions`)
3. Desde el historial puedes ver el detalle, descargar el reporte o eliminar ejecuciones

## Estructura del proyecto

```
lib/
├── file_processor/               # Contexto y lógica de negocio
│   ├── core_adapter.ex           # Puente entre Phoenix y el core
│   ├── execution_helpers.ex      # Helpers de presentación (fechas, íconos, métricas)
│   ├── executions.ex             # Contexto Ecto para ejecuciones
│   ├── executions/
│   │   └── execution.ex          # Schema Ecto
│   ├── report_builder.ex         # Construcción de reportes por modo
│   └── repo.ex
│
├── file_processor/               # Core de procesamiento (Elixir puro, sin Phoenix)
│   ├── coordinador.ex            # Coordinator del patrón Coordinator/Worker
│   ├── worker.ex                 # Worker para procesamiento paralelo
│   ├── procesador_archivos.ex    # Orquestador principal
│   ├── csv_parser.ex             # Parser de archivos CSV
│   ├── json_parser.ex            # Parser de archivos JSON
│   ├── log_parser.ex             # Parser de archivos LOG
│   └── procesar_con_manejo_errores.ex  # Procesamiento con detección de errores
│
└── file_processor_web/           # Capa web Phoenix
    ├── controllers/
    │   ├── execution_controller.ex
    │   ├── processing_controller.ex
    │   └── execution_html/       # Templates de ejecuciones
    ├── router.ex
    └── endpoint.ex
```

## Tests

```bash
mix test
```

## Tecnologías

- [Phoenix Framework](https://www.phoenixframework.org/) 1.8
- [Ecto](https://hexdocs.pm/ecto) + PostgreSQL
- [Tailwind CSS](https://tailwindcss.com/) + [DaisyUI](https://daisyui.com/)
- [Chart.js](https://www.chartjs.org/) — gráfico de benchmark