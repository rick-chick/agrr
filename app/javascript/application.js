// Entry point for the build script in your package.json
// ライブラリ管理: npm/jsbundling-rails
import "@hotwired/turbo-rails"
import "./controllers" // Stimulusコントローラーの自動読み込み
import "leaflet";
import "leaflet/dist/leaflet.css";

// Chart.jsをグローバルに登録（cultivation_results.jsとtemperature_chart.jsで使用）
import Chart from 'chart.js/auto';
import annotationPlugin from 'chartjs-plugin-annotation';

// アノテーションプラグインを登録（Chart.js v4の正しい構文）
Chart.register(annotationPlugin);
window.Chart = Chart;

import "./crop_form";
import "./crop_selection";
import "./fields";
import "./progress_bar";
import "./optimizing";
import "./temperature_chart";
import "./cultivation_results";
import "./custom_gantt_chart";
import "./climate_chart";

// Google Analytics 4 統合
import "./integrations/analytics_integration";