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
      crop_palette_communication_error: t('js.crop_palette.communication_error')
    }
  end
  
  # 動的なパラメータ付きメッセージ用（JavaScript側で補間）
  def js_i18n_templates
    {
      crop_palette_crop_types_limit: t('js.crop_palette.crop_types_limit', max_types: '__MAX_TYPES__', current_types: '__CURRENT_TYPES__'),
      crop_palette_crop_add_failed: t('js.crop_palette.crop_add_failed', message: '__MESSAGE__')
    }
  end
end

