import { Controller } from "@hotwired/stimulus";

// Crop form nested fields controller
// - Add new crop stage blocks
// - Remove existing/newly-added stage blocks (toggle _destroy when persisted)
export default class extends Controller {
  static targets = ["stages"];

  connect() {
    // Keep an index for newly added stages
    this.stageIndex = this.element.querySelectorAll(".crop-stage-item").length;
  }

  addStage(event) {
    event.preventDefault();
    const container = this.stagesTarget;
    const newStageHtml = this._buildNewStageTemplate(this.stageIndex);
    container.insertAdjacentHTML("beforeend", newStageHtml);
    this.stageIndex += 1;
  }

  removeStage(event) {
    event.preventDefault();
    const button = event.currentTarget;
    const stageItem = button.closest(".crop-stage-item");
    if (!stageItem) return;

    const destroyFlag = stageItem.querySelector(".destroy-flag");
    if (destroyFlag && destroyFlag.value !== "false") {
      // Existing record: mark _destroy and hide
      destroyFlag.value = "1";
      stageItem.style.display = "none";
    } else {
      // Newly added: remove element
      stageItem.remove();
    }
  }

  _buildNewStageTemplate(index) {
    // getI18nMessage is provided globally by i18n_helper.js
    const namePlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropStageNamePlaceholder", "e.g., Germination, Vegetative growth")
      : "e.g., Germination, Vegetative growth";
    const orderPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropOrderPlaceholder", "0")
      : "0";
    const baseTempPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropBaseTemperaturePlaceholder", "e.g., 5.0")
      : "e.g., 5.0";
    const optimalMinPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropOptimalMinPlaceholder", "e.g., 15.0")
      : "e.g., 15.0";
    const optimalMaxPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropOptimalMaxPlaceholder", "e.g., 25.0")
      : "e.g., 25.0";
    const lowStressPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropLowStressPlaceholder", "e.g., 10.0")
      : "e.g., 10.0";
    const highStressPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropHighStressPlaceholder", "e.g., 30.0")
      : "e.g., 30.0";
    const frostThresholdPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropFrostThresholdPlaceholder", "e.g., 0.0")
      : "e.g., 0.0";
    const sterilityPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropSterilityRiskPlaceholder", "e.g., 35.0")
      : "e.g., 35.0";
    const dailyNPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropDailyUptakeNPlaceholder", "e.g., 0.5")
      : "e.g., 0.5";
    const dailyPPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropDailyUptakePPlaceholder", "e.g., 0.2")
      : "e.g., 0.2";
    const dailyKPlaceholder = (typeof getI18nMessage === "function")
      ? getI18nMessage("jsCropDailyUptakeKPlaceholder", "e.g., 0.8")
      : "e.g., 0.8";

    return `
      <div class="nested-fields crop-stage-item">
        <div class="nested-fields-header">
          <h4 class="nested-title">生育ステージ</h4>
          <input type="hidden" name="crop[crop_stages_attributes][${index}][_destroy]" value="false" class="destroy-flag">
          <button type="button" class="btn btn-danger btn-sm remove-crop-stage" data-action="click->crop-form#removeStage">削除</button>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label class="form-label" for="crop_crop_stages_attributes_${index}_name">ステージ名</label>
            <input type="text" name="crop[crop_stages_attributes][${index}][name]"
                   id="crop_crop_stages_attributes_${index}_name"
                   class="form-control" placeholder="${namePlaceholder}">
          </div>

          <div class="form-group">
            <label class="form-label" for="crop_crop_stages_attributes_${index}_order">順序</label>
            <input type="number" name="crop[crop_stages_attributes][${index}][order]"
                   id="crop_crop_stages_attributes_${index}_order"
                   class="form-control" min="0" placeholder="${orderPlaceholder}">
          </div>
        </div>

        <div class="nested-section">
          <h5 class="nested-subtitle">🌡️ 温度要件</h5>
          <div class="requirement-fields">
            <input type="hidden" name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][_destroy]" value="false" class="destroy-flag">
            <div class="form-row">
              <div class="form-group">
                <label class="form-label">最低限界温度 (°C)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][base_temperature]" class="form-control" step="0.1" placeholder="${baseTempPlaceholder}">
              </div>
              <div class="form-group">
                <label class="form-label">最適温度 最小 (°C)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][optimal_min]" class="form-control" step="0.1" placeholder="${optimalMinPlaceholder}">
              </div>
              <div class="form-group">
                <label class="form-label">最適温度 最大 (°C)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][optimal_max]" class="form-control" step="0.1" placeholder="${optimalMaxPlaceholder}">
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label class="form-label">低温ストレス閾値 (°C)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][low_stress_threshold]" class="form-control" step="0.1" placeholder="${lowStressPlaceholder}">
              </div>
              <div class="form-group">
                <label class="form-label">高温ストレス閾値 (°C)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][high_stress_threshold]" class="form-control" step="0.1" placeholder="${highStressPlaceholder}">
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label class="form-label">霜害閾値 (°C)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][frost_threshold]" class="form-control" step="0.1" placeholder="${frostThresholdPlaceholder}">
              </div>
              <div class="form-group">
                <label class="form-label">不稔リスク閾値 (°C)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][temperature_requirement_attributes][sterility_risk_threshold]" class="form-control" step="0.1" placeholder="${sterilityPlaceholder}">
              </div>
            </div>
          </div>
        </div>

        <div class="nested-section">
          <h5 class="nested-subtitle">☀️ 日照要件</h5>
          <div class="requirement-fields">
            <input type="hidden" name="crop[crop_stages_attributes][${index}][sunshine_requirement_attributes][_destroy]" value="false" class="destroy-flag">
            <div class="form-row">
              <div class="form-group">
                <label class="form-label">最低日照時間 (時間)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][sunshine_requirement_attributes][minimum_sunshine_hours]" class="form-control" step="0.1" placeholder="e.g., 4.0">
              </div>
              <div class="form-group">
                <label class="form-label">目標日照時間 (時間)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][sunshine_requirement_attributes][target_sunshine_hours]" class="form-control" step="0.1" placeholder="e.g., 8.0">
              </div>
            </div>
          </div>
        </div>

        <div class="nested-section">
          <h5 class="nested-subtitle">🌱 栄養素要件</h5>
          <div class="requirement-fields">
            <input type="hidden" name="crop[crop_stages_attributes][${index}][nutrient_requirement_attributes][_destroy]" value="false" class="destroy-flag">
            <div class="form-row">
              <div class="form-group">
                <label class="form-label">窒素 (N) 吸収量 (g/m²/day)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][nutrient_requirement_attributes][daily_uptake_n]" class="form-control" step="0.1" placeholder="${dailyNPlaceholder}">
              </div>
              <div class="form-group">
                <label class="form-label">リン (P) 吸収量 (g/m²/day)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][nutrient_requirement_attributes][daily_uptake_p]" class="form-control" step="0.1" placeholder="${dailyPPlaceholder}">
              </div>
              <div class="form-group">
                <label class="form-label">カリウム (K) 吸収量 (g/m²/day)</label>
                <input type="number" name="crop[crop_stages_attributes][${index}][nutrient_requirement_attributes][daily_uptake_k]" class="form-control" step="0.1" placeholder="${dailyKPlaceholder}">
              </div>
            </div>
          </div>
        </div>
      </div>
    `;
  }
}


