// Entry point for the build script in your package.json
// ライブラリ管理: npm/jsbundling-rails
import "@hotwired/turbo-rails"

import "./controllers" // Stimulusコントローラーの自動読み込み
import "leaflet";
import "leaflet/dist/leaflet.css";
import "./cable_subscription"; // Action Cable サブスクリプション

// Chart.jsをグローバルに登録（temperature_chart.js / climate_chart.js で使用）
import Chart from 'chart.js/auto';
import annotationPlugin from 'chartjs-plugin-annotation';

// アノテーションプラグインを登録（Chart.js v4の正しい構文）
Chart.register(annotationPlugin);
window.Chart = Chart;

// npmライブラリを使用するファイルのみバンドル
import "./fields"; // Leaflet使用（バンドル必須）
import "./temperature_chart"; // Chart.js使用（バンドル必須）
import "./climate_chart"; // Chart.js使用（バンドル必須）

// 以下はpropshaftで直接配信（バンドルしない、レイアウトで個別読み込み）
// - crop_form.js
// - custom_gantt_chart.js
// - optimizing.js (ActionCableはグローバルで利用可能)

// Google Analytics 4 統合
import "./integrations/analytics_integration";