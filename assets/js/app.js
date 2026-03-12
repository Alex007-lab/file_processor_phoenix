// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/file_processor";
import topbar from "../vendor/topbar";

// =====================================
// CSRF
// =====================================
const csrfToken = document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content");

// =====================================
// HOOKS
// =====================================
const Hooks = {};

Hooks.DropZone = {
    mounted() {
        const zone = this.el;

        zone.addEventListener("dragover", (e) => {
            e.preventDefault();
            zone.classList.add("border-blue-400", "bg-blue-50");
        });

        zone.addEventListener("dragleave", (e) => {
            zone.classList.remove("border-blue-400", "bg-blue-50");
        });

        zone.addEventListener("drop", (e) => {
            zone.classList.remove("border-blue-400", "bg-blue-50");
            // No llamamos preventDefault ni stopPropagation aquí —
            // LiveView necesita recibir el evento drop para procesar los archivos
        });
    },
};

// =====================================
// LIVE SOCKET
// =====================================
const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: { ...colocatedHooks, ...Hooks },
});

// =====================================
// TOPBAR LOADING
// =====================================
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });

window.addEventListener("phx:page-loading-start", () => topbar.show(300));
window.addEventListener("phx:page-loading-stop", () => {
    topbar.hide();
    renderBenchmarkChart();
});

// =====================================
// CONNECT LIVEVIEW
// =====================================
liveSocket.connect();
window.liveSocket = liveSocket;

// =====================================
// CHART.JS BENCHMARK RENDER
// =====================================

let benchmarkChartInstance = null;

function renderBenchmarkChart() {
    const canvas = document.getElementById("benchmarkChart");
    if (!canvas) return;

    const seq = parseFloat(canvas.dataset.secuencial || 0);
    const par = parseFloat(canvas.dataset.paralelo || 0);

    if (benchmarkChartInstance) {
        benchmarkChartInstance.destroy();
    }

    const isDark = document.documentElement.dataset.theme === "dark";
    const gridColor = isDark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.06)";
    const labelColor = isDark ? "#d1d5db" : "#374151";

    benchmarkChartInstance = new Chart(canvas, {
        type: "bar",
        data: {
            labels: ["📋 Secuencial", "⚡ Paralelo"],
            datasets: [
                {
                    label: "Tiempo (ms)",
                    data: [seq, par],
                    backgroundColor: [
                        "rgba(59,130,246,0.8)",
                        "rgba(34,197,94,0.8)",
                    ],
                    borderColor: ["rgba(59,130,246,1)", "rgba(34,197,94,1)"],
                    borderWidth: 2,
                    borderRadius: 8,
                    borderSkipped: false,
                },
            ],
        },
        options: {
            responsive: true,
            animation: {
                duration: 800,
            },
            plugins: {
                legend: { display: false },
                tooltip: {
                    callbacks: {
                        label: (ctx) => ` ${ctx.parsed.y} ms`,
                    },
                },
            },
            scales: {
                x: {
                    grid: { color: gridColor },
                    ticks: {
                        color: labelColor,
                        font: {
                            size: 13,
                            weight: "600",
                        },
                    },
                },
                y: {
                    beginAtZero: true,
                    grid: { color: gridColor },
                    ticks: {
                        color: labelColor,
                        callback: (val) => val + " ms",
                    },
                },
            },
        },
    });
}

document.addEventListener("DOMContentLoaded", renderBenchmarkChart);

// =====================================
// LIVE RELOAD DEV FEATURES
// =====================================
if (process.env.NODE_ENV === "development") {
    window.addEventListener(
        "phx:live_reload:attached",
        ({ detail: reloader }) => {
            reloader.enableServerLogs();

            let keyDown;
            window.addEventListener("keydown", (e) => (keyDown = e.key));
            window.addEventListener("keyup", () => (keyDown = null));

            window.addEventListener(
                "click",
                (e) => {
                    if (keyDown === "c") {
                        e.preventDefault();
                        e.stopImmediatePropagation();
                        reloader.openEditorAtCaller(e.target);
                    } else if (keyDown === "d") {
                        e.preventDefault();
                        e.stopImmediatePropagation();
                        reloader.openEditorAtDef(e.target);
                    }
                },
                true,
            );

            window.liveReloader = reloader;
        },
    );
}
