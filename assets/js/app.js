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
// LIVE SOCKET
// =====================================
const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: { ...colocatedHooks },
});

// =====================================
// TOPBAR LOADING
// =====================================
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });

window.addEventListener("phx:page-loading-start", () => topbar.show(300));
window.addEventListener("phx:page-loading-stop", () => {
    topbar.hide();
    renderBenchmarkChart(); // Render chart after LiveView updates
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

    const sec = parseFloat(canvas.dataset.secuencial || 0);
    const par = parseFloat(canvas.dataset.paralelo || 0);

    // Destroy previous instance to avoid duplicates
    if (benchmarkChartInstance) {
        benchmarkChartInstance.destroy();
    }

    benchmarkChartInstance = new Chart(canvas, {
        type: "bar",
        data: {
            labels: ["Secuencial", "Paralelo"],
            datasets: [
                {
                    label: "Tiempo (ms)",
                    data: [sec, par],
                    borderWidth: 1,
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
            },
            scales: {
                y: {
                    beginAtZero: true,
                },
            },
        },
    });
}

// Initial load
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
