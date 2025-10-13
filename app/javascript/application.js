// Entry point for the build script in your package.json
// ライブラリ管理: npm/jsbundling-rails
import "@hotwired/turbo-rails"
import "./controllers" // Stimulusコントローラーの自動読み込み
import "leaflet";
import "leaflet/dist/leaflet.css";
import "./crop_form";
import "./crop_selection";
import "./fields";
import "./progress_bar";
import "./optimizing";
// import "./temperature_chart"; // 一時的にコメントアウト（chart.jsの問題）