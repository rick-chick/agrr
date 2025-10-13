// Entry point for the build script in your package.json
// ライブラリ管理: npm/jsbundling-rails
import "@hotwired/turbo-rails"
import "./controllers" // Stimulusコントローラーの自動読み込み
import "leaflet";
import "leaflet/dist/leaflet.css";

// Chart.jsをグローバルに登録（cultivation_results.jsとtemperature_chart.jsで使用）
import Chart from 'chart.js/auto';
window.Chart = Chart;

import "./crop_form";
import "./crop_selection";
import "./fields";
import "./progress_bar";
import "./optimizing";
import "./temperature_chart";
import "./cultivation_results";