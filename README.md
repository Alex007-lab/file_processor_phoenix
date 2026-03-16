<div align="center">

# 🗂️ FileProcessor

**Procesador de archivos en tiempo real con Phoenix LiveView**

Aplicación web para procesar archivos CSV, JSON y LOG con soporte para procesamiento secuencial, paralelo y benchmark comparativo.

[![Elixir](https://img.shields.io/badge/Elixir-1.14+-4B275F?style=flat-square&logo=elixir&logoColor=white)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-FF6600?style=flat-square&logo=phoenixframework&logoColor=white)](https://www.phoenixframework.org)
[![LiveView](https://img.shields.io/badge/LiveView-1.1-FF6600?style=flat-square&logo=phoenixframework&logoColor=white)](https://hexdocs.pm/phoenix_live_view)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-336791?style=flat-square&logo=postgresql&logoColor=white)](https://www.postgresql.org)

</div>

---

## ✨ Características

| Característica | Descripción |
|---|---|
| 📋 **Secuencial** | Procesa archivos uno por uno |
| ⚡ **Paralelo** | Procesamiento simultáneo con el patrón Coordinator/Worker |
| 📊 **Benchmark** | Compara rendimiento secuencial vs paralelo con gráfica Chart.js |
| 🔴 **Tiempo real** | Feedback por archivo durante el procesamiento (LiveView) |
| 📁 **Drag & drop** | Subida de archivos con barra de progreso |
| ⚠️ **Detección parcial** | Archivos con datos corruptos se marcan como `partial` |
| 🕓 **Historial** | Filtros por modo y fecha, paginación dinámica |
| 🔒 **Modal de confirmación** | Para eliminar ejecuciones sin recargar la página |
| 🌙 **Tema oscuro** | Soporte completo en todos los componentes |

---

## 📂 Formatos soportados

| Formato | Tipo de datos | Métricas extraídas |
|---|---|---|
| `.csv` | Datos de ventas | Registros válidos, productos únicos, ventas totales |
| `.json` | Usuarios y sesiones | Total usuarios, usuarios activos, total sesiones |
| `.log` | Niveles de sistema | Total líneas, DEBUG / INFO / WARN / ERROR / FATAL |

---

## 🚦 Estados de ejecución

| Estado | Descripción |
|---|---|
| ✅ `success` | Todos los archivos procesados correctamente |
| ⚠️ `partial` | Uno o más archivos tienen líneas o registros inválidos |
| ❌ `error` | Todos los archivos fallaron |

---

## ⚙️ Requisitos

- **Elixir** 1.14+
- **Erlang/OTP** 25+
- **PostgreSQL** 14+

---

## 🚀 Configuración

```bash
# Instalar dependencias y crear la base de datos
mix setup

# Iniciar el servidor
mix phx.server
```

Visita [localhost:4000](http://localhost:4000) — la ruta raíz redirige automáticamente a `/processing`.

---

## 📖 Uso

```
1. /processing  →  Sube archivos (CSV, JSON, LOG)
                   Elige modo: Secuencial | Paralelo | Benchmark
                   Progreso en tiempo real por archivo

2. /executions  →  Historial con filtros por modo y fecha
                   Paginación dinámica (10 por página)
                   Modal de confirmación para eliminar

3. /executions/:id  →  Reporte detallado con métricas visuales
                        Gráfica de benchmark (Chart.js)
                        Descarga del reporte como .txt
```

---

## 🏗️ Estructura del proyecto

```
lib/
├── file_processor/                   # 🧠 Contexto y lógica de negocio
│   ├── core_adapter.ex               #    Puente Phoenix ↔ core Elixir puro
│   ├── execution_helpers.ex          #    Helpers de presentación
│   ├── executions.ex                 #    Queries, filtros, paginación y estadísticas
│   ├── executions/
│   │   └── execution.ex              #    Schema Ecto
│   ├── report_builder.ex             #    Construcción de reportes por modo
│   └── repo.ex
│
├── file_processor/                   # ⚙️  Core de procesamiento (Elixir puro)
│   ├── coordinador.ex                #    Patrón Coordinator/Worker
│   ├── worker.ex
│   ├── procesador_archivos.ex        #    Orquestador principal
│   ├── csv_parser.ex
│   ├── json_parser.ex
│   ├── log_parser.ex
│   └── procesar_con_manejo_errores.ex
│
└── file_processor_web/               # 🌐 Capa web Phoenix
    ├── live/
    │   ├── processing_live.ex        #    Subida y procesamiento en tiempo real
    │   ├── execution_live.ex         #    Historial con filtros, paginación y modal
    │   ├── execution_show_live.ex    #    Reporte detallado por archivo
    │   └── *.html.heex
    ├── controllers/
    │   ├── execution_controller.ex   #    download · delete · delete_all
    │   ├── execution_html.ex         #    Helpers de parseo para LiveViews
    │   └── page_controller.ex        #    Redirige / → /processing
    ├── router.ex
    └── endpoint.ex

assets/
└── js/
    └── app.js                        # Hook DropZone + renderBenchmarkChart

test/
├── file_processor/
│   ├── executions_test.exs           # CRUD, filtros, paginación, estadísticas
│   └── report_builder_test.exs       # Formato de reportes por tipo de archivo
├── file_processor_web/
│   ├── execution_html_test.exs       # Helpers de parseo y presentación
│   ├── controllers/
│   │   ├── execution_controller_test.exs
│   │   └── page_controller_test.exs
│   └── live/
│       ├── execution_live_test.exs   # Filtros, paginación y modal
│       └── execution_show_live_test.exs
└── support/
    └── fixtures/
        └── executions_fixtures.ex
```

---

## 🧪 Tests

```bash
mix test
```

---

## 🛠️ Tecnologías

<div align="center">

| | Tecnología | Uso |
|---|---|---|
| ![Elixir](https://img.shields.io/badge/-Elixir-4B275F?style=flat-square&logo=elixir&logoColor=white) | Phoenix Framework 1.8 | Framework web |
| ![LiveView](https://img.shields.io/badge/-LiveView-FF6600?style=flat-square&logo=phoenixframework&logoColor=white) | Phoenix LiveView 1.1 | Interfaz reactiva en tiempo real |
| ![Postgres](https://img.shields.io/badge/-PostgreSQL-336791?style=flat-square&logo=postgresql&logoColor=white) | Ecto + PostgreSQL | Persistencia |
| ![Tailwind](https://img.shields.io/badge/-Tailwind_CSS-38B2AC?style=flat-square&logo=tailwind-css&logoColor=white) | Tailwind CSS v4 + DaisyUI | Estilos |
| ![Chart.js](https://img.shields.io/badge/-Chart.js-FF6384?style=flat-square&logo=chart.js&logoColor=white) | Chart.js 4.4 | Gráfico benchmark |

</div>

---

## 👥 Equipo

| Desarrollador | Rol |
|---|---|
| **Alex Gomez** | Fullstack · LiveView · Core adapter · Tests · UX · historial y reporte |
| **Sharon Anette** | Frontend  LiveView · historial y reporte |

---

<div align="center">

*Proyecto académico — Migración a Phoenix LiveView*

</div>