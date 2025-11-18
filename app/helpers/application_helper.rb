# frozen_string_literal: true

module ApplicationHelper
  # JavaScriptから参照するi18nメッセージをdata属性として返す
  def js_i18n_data
    {
      # fields.js validation messages
      fields_validation_coordinates_numeric: t('fields.js.validation.coordinates_must_be_numeric'),
      fields_validation_latitude_range: t('fields.js.validation.latitude_range'),
      fields_validation_longitude_range: t('fields.js.validation.longitude_range'),
      
      # crop_palette_drag.js messages
      crop_palette_plan_id_missing: t('js.crop_palette.plan_id_missing'),
      crop_palette_communication_error: t('js.crop_palette.communication_error'),
      
      # custom_gantt_chart.js messages
      js_gantt_optimization_failed: t('js.gantt.optimization_failed'),
      js_gantt_update_failed: t('js.gantt.update_failed'),
      js_gantt_fetch_error: t('js.gantt.fetch_error'),
      js_gantt_field_info_error: t('js.gantt.field_info_error'),
      js_gantt_communication_error: t('js.gantt.communication_error'),
      js_gantt_invalid_area: t('js.gantt.invalid_area'),
      js_gantt_field_add_failed: t('js.gantt.field_add_failed'),
      js_gantt_field_delete_failed: t('js.gantt.field_delete_failed'),
      js_gantt_add_field_button: t('js.gantt.add_field_button'),
      js_gantt_adding_field_loading: t('js.gantt.adding_field_loading'),
      
      # crop_form.js placeholders
      js_crop_stage_name_placeholder: t('js.crop_form.stage_name_placeholder'),
      js_crop_order_placeholder: t('js.crop_form.order_placeholder'),
      js_crop_base_temperature_placeholder: t('js.crop_form.base_temperature_placeholder'),
      js_crop_optimal_min_placeholder: t('js.crop_form.optimal_min_placeholder'),
      js_crop_optimal_max_placeholder: t('js.crop_form.optimal_max_placeholder'),
      js_crop_low_stress_placeholder: t('js.crop_form.low_stress_placeholder'),
      js_crop_high_stress_placeholder: t('js.crop_form.high_stress_placeholder'),
      js_crop_frost_threshold_placeholder: t('js.crop_form.frost_threshold_placeholder'),
      js_crop_sterility_risk_placeholder: t('js.crop_form.sterility_risk_placeholder'),
      js_crop_minimum_sunshine_placeholder: t('js.crop_form.minimum_sunshine_placeholder'),
      js_crop_target_sunshine_placeholder: t('js.crop_form.target_sunshine_placeholder'),
      js_crop_daily_uptake_n_placeholder: t('js.crop_form.daily_uptake_n_placeholder'),
      js_crop_daily_uptake_p_placeholder: t('js.crop_form.daily_uptake_p_placeholder'),
      js_crop_daily_uptake_k_placeholder: t('js.crop_form.daily_uptake_k_placeholder'),
      
      # crop_selection.js messages
      js_crop_selection_hint: t('js.crop_selection.hint_select'),
      
      # cultivation_results.js messages
      js_cultivation_load_error: t('js.cultivation_results.load_error'),
      js_cultivation_data_error: t('js.cultivation_results.data_error'),
      js_cultivation_temp_max_label: t('js.cultivation_results.temp_max_label'),
      js_cultivation_temp_mean_label: t('js.cultivation_results.temp_mean_label'),
      js_cultivation_temp_min_label: t('js.cultivation_results.temp_min_label'),
      js_cultivation_optimal_range_label: t('js.cultivation_results.optimal_range_label'),
      js_cultivation_date_label: t('js.cultivation_results.date_label'),
      js_cultivation_temp_axis_label: t('js.cultivation_results.temp_axis_label'),
      js_cultivation_gdd_label: t('js.cultivation_results.gdd_label'),
      js_cultivation_gdd_axis_label: t('js.cultivation_results.gdd_axis_label'),
      js_cultivation_no_risks: t('js.cultivation_results.no_risks'),
      
      # plans_show.js messages
      js_plans_load_error: t('js.plans.load_error')
    }
  end
  
  # 動的なパラメータ付きメッセージ用（JavaScript側で補間）
  def js_i18n_templates
    {
      crop_palette_crop_types_limit: t('js.crop_palette.crop_types_limit', max_types: '__MAX_TYPES__', current_types: '__CURRENT_TYPES__'),
      crop_palette_crop_add_failed: t('js.crop_palette.crop_add_failed', message: '__MESSAGE__'),
      
      # custom_gantt_chart.js templates
      js_gantt_confirm_delete_field: t('js.gantt.confirm_delete_field', field_name: '__FIELD_NAME__'),
      js_gantt_confirm_delete_crop: t('js.gantt.confirm_delete_crop', crop_name: '__CROP_NAME__'),
      
      # crop_selection.js templates
      js_crop_selection_max_message: t('js.crop_selection.max_crops_message', max: '__MAX__'),
      
      # cultivation_results.js templates
      js_cultivation_gdd_target_label: t('js.cultivation_results.gdd_target_label', target: '__TARGET__')
    }
  end

  # 現在のページが指定されたパスと一致するか判定
  def current_page?(path)
    request.path == path || request.path.start_with?("#{path}/")
  end

  # ナビゲーションリンクのクラスを返す（現在地の強調用）
  def nav_link_class(path, base_class = "nav-link")
    classes = [base_class]
    classes << "nav-link-active" if current_page?(path)
    classes.join(" ")
  end

  # ドロップダウンアイテムのクラスを返す（現在地の強調用）
  def nav_dropdown_item_class(path, base_class = "nav-dropdown-item")
    classes = [base_class]
    classes << "nav-dropdown-item-active" if current_page?(path)
    classes.join(" ")
  end

  # ============================================
  # UI/UX統一: スタイルシート読み込み順序の統一
  # ============================================
  
  # コアデザインシステムのスタイルシートを読み込む（必須・最初に読み込む）
  def render_core_stylesheets
    capture do
      concat stylesheet_link_tag("core/variables", "data-turbo-track": "reload")
      concat stylesheet_link_tag("core/reset", "data-turbo-track": "reload")
    end
  end

  # ユーティリティクラスのスタイルシートを読み込む
  def render_utility_stylesheets
    stylesheet_link_tag("utilities", "data-turbo-track": "reload")
  end

  # 共通コンポーネントのスタイルシートを読み込む
  # デフォルトコンポーネントリストは統一性のため、application.html.erbで使用される全コンポーネントを含む
  def render_component_stylesheets(components: nil)
    default_components = [
      "components/buttons",
      "components/forms",
      "components/navbar",
      "components/cards",
      "components/layouts",
      "components/footer",
      "components/crop_selection",
      "components/farm-cards",
      "components/undo_toast"
    ]
    
    components_to_load = components || default_components
    
    capture do
      components_to_load.each do |component|
        concat stylesheet_link_tag(component, "data-turbo-track": "reload")
      end
    end
  end

  # 機能固有のスタイルシートを読み込む
  def render_feature_stylesheets(features: [])
    return "" if features.empty?
    
    capture do
      features.each do |feature|
        concat stylesheet_link_tag(feature, "data-turbo-track": "reload")
      end
    end
  end

  # 共通JavaScriptを読み込む
  def render_common_javascripts(include_shared_systems: true)
    capture do
      concat javascript_include_tag("application", "data-turbo-track": "reload", type: "module")
      concat javascript_include_tag("i18n_helper", "data-turbo-track": "reload", defer: true)
      
      if include_shared_systems
        concat javascript_include_tag("svg_drag_utils", "data-turbo-track": "reload", defer: true)
        concat javascript_include_tag("shared/notification_system", "data-turbo-track": "reload", defer: true)
        concat javascript_include_tag("shared/dialog_system", "data-turbo-track": "reload", defer: true)
        concat javascript_include_tag("shared/loading_system", "data-turbo-track": "reload", defer: true)
      end
    end
  end
end

