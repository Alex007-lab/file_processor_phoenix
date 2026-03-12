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
assets/
└── js/
    └── app.js                        # Hook DropZone para drag & drop en LiveView

file_processor_phoenix/
│
├── assets/                          # Recursos frontend (JS, CSS)
│   ├── css/
│   └── js/
│       └── app.js                   # Inicializa LiveView, hooks JS y manejo de eventos en el navegador
│
├── config/                          # Configuración de la aplicación Phoenix
│
├── lib/
│   │
│   ├── file_processor/              # Contexto y lógica de negocio principal
│   │   ├── application.ex           # Punto de inicio de la aplicación y supervisores
│   │   ├── core_adapter.ex          # Conecta Phoenix con el procesador de archivos del core
│   │   ├── coordinator.ex           # Coordina workers para procesamiento paralelo
│   │   ├── worker.ex                # Worker que procesa archivos individuales
│   │   ├── procesador_archivos.ex   # Orquestador principal del procesamiento de archivos
│   │   ├── procesar_con_manejo_errores.ex # Procesamiento con captura y reporte de errores
│   │   ├── csv_parser.ex            # Parser para archivos CSV
│   │   ├── json_parser.ex           # Parser para archivos JSON
│   │   ├── log_parser.ex            # Parser para archivos LOG
│   │   ├── report_builder.ex        # Genera reportes a partir de los resultados del procesamiento
│   │   ├── execution_helpers.ex     # Funciones auxiliares para métricas, formato de datos e íconos
│   │   ├── executions.ex            # Contexto Ecto para consultar ejecuciones y aplicar filtros
│   │   ├── repo.ex                  # Configuración del repositorio Ecto (acceso a base de datos)
│   │   └── executions/
│   │       └── execution.ex         # Schema Ecto que representa una ejecución en la base de datos
│   │
│   ├── file_processor_web/          # Capa web de Phoenix
│   │   │
│   │   ├── components/              # Componentes reutilizables de UI
│   │   │   └── core_components.ex   # Componentes Phoenix como tablas, botones y alerts
│   │   │
│   │   ├── layouts/                 # Layouts globales de la aplicación
│   │   │   ├── layouts.ex           # Define los layouts disponibles
│   │   │   └── root.html.heex       # Layout principal de la aplicación
│   │   │
│   │   ├── controllers/             # Controladores HTTP tradicionales
│   │   │   ├── execution_controller.ex   # Controlador para historial y detalle de ejecuciones
│   │   │   ├── processing_controller.ex  # Controlador para procesamiento tradicional (fallback)
│   │   │   ├── execution_html.ex         # Renderiza templates de ejecuciones
│   │   │   ├── processing_html.ex        # Renderiza templates de procesamiento
│   │   │   ├── page_controller.ex        # Controlador de páginas básicas
│   │   │   ├── page_html.ex              # Templates de páginas básicas
│   │   │   ├── error_html.ex             # Templates de errores HTML
│   │   │   └── error_json.ex             # Respuestas de error en formato JSON
│   │   │
│   │   │   └── execution_html/
│   │   │       ├── index.html.heex       # Vista del historial de ejecuciones
│   │   │       └── show_with_styles.html.heex # Vista detallada de una ejecución con estilos
│   │   │
│   │   ├── live/                    # LiveViews para interfaces dinámicas
│   │   │   ├── processing_live.ex        # LiveView para subir archivos y procesarlos en tiempo real
│   │   │   ├── execution_live.ex         # LiveView que muestra el historial de ejecuciones
│   │   │   ├── execution_live.html.heex  # Vista del historial usando LiveView
│   │   │   ├── execution_show_live.ex    # LiveView para mostrar el detalle de una ejecución
│   │   │   └── execution_show_live.html.heex # Vista del reporte detallado de ejecución
│   │   │
│   │   ├── router.ex                # Define rutas HTTP y LiveView de la aplicación
│   │   ├── endpoint.ex              # Punto de entrada del servidor Phoenix
│   │   ├── telemetry.ex             # Métricas y monitoreo de la aplicación
│   │   └── gettext.ex               # Internacionalización (traducciones)
│   │
│   ├── file_processor.ex            # Módulo raíz del contexto principal
│   └── file_processor_web.ex        # Helpers y macros para controllers, views y LiveViews
│
├── output/                          # Carpeta donde se guardan los reportes generados
│
├── priv/
│   ├── repo/
│   │   └── migrations/              # Migraciones de base de datos
│   └── uploads/                     # Archivos subidos para procesamiento
│
├── test/                            # Pruebas unitarias y de integración
│
├── mix.exs                          # Configuración del proyecto y dependencias
├── mix.lock                         # Versiones exactas de dependencias
├── README.md                        # Documentación del proyecto
├── CHANGELOG.md                     # Registro de cambios del proyecto
└── .formatter.exs                   # Configuración de formateo de código
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
