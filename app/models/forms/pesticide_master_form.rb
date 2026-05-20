# frozen_string_literal: true

module Forms
  class PesticideMasterForm
    include Forms::HtmlFormSupport

    ATTR_KEYS = %i[name active_ingredient description crop_id pest_id is_reference region user_id].freeze

    attr_accessor :name, :active_ingredient, :description, :crop_id, :pest_id, :is_reference, :region, :user_id
    attr_reader :id, :pesticide_usage_constraint, :pesticide_application_detail

    def pesticide_usage_constraint_attributes=(attrs)
      @pesticide_usage_constraint = PesticideUsageConstraintMasterForm.from_attrs(attrs)
    end

    def pesticide_application_detail_attributes=(attrs)
      @pesticide_application_detail = PesticideApplicationDetailMasterForm.from_attrs(attrs)
    end

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("Pesticide")
    end

    def self.from_snapshot(snapshot)
      obj = new
      obj.instance_variable_set(:@id, snapshot.id)
      obj.instance_variable_set(:@_new_record, snapshot.new_record?)
      obj.name = snapshot.name
      obj.active_ingredient = snapshot.active_ingredient
      obj.description = snapshot.description
      obj.crop_id = snapshot.crop_id
      obj.pest_id = snapshot.pest_id
      obj.is_reference = snapshot.is_reference
      obj.region = snapshot.region
      obj.user_id = snapshot.user_id
      obj.instance_variable_set(
        :@pesticide_usage_constraint,
        PesticideUsageConstraintMasterForm.from_attrs(snapshot.pesticide_usage_constraint_attributes)
      )
      obj.instance_variable_set(
        :@pesticide_application_detail,
        PesticideApplicationDetailMasterForm.from_attrs(snapshot.pesticide_application_detail_attributes)
      )
      snapshot.error_messages.each { |msg| obj.errors.add(:base, msg) }
      obj
    end

    # 失敗再描画用。Strong params 由来の Hash / ActionController::Parameters を想定（ネストは symbol キー）。
    # @param params_hash [Hash, ActionController::Parameters]
    # @return [void]
    def apply_params!(params_hash)
      h = params_hash.to_h.deep_symbolize_keys
      ATTR_KEYS.each { |k| send("#{k}=", h[k]) if h.key?(k) }
      if h.key?(:pesticide_usage_constraint_attributes)
        uc_param = h[:pesticide_usage_constraint_attributes]
        uc_hash = if uc_param.respond_to?(:to_unsafe_h)
                    uc_param.to_unsafe_h.deep_symbolize_keys
                  else
                    uc_param.to_h.symbolize_keys
                  end
        base = @pesticide_usage_constraint&.to_nested_attributes || {}
        @pesticide_usage_constraint = PesticideUsageConstraintMasterForm.from_attrs(base.merge(uc_hash))
      end
      if h.key?(:pesticide_application_detail_attributes)
        ad_param = h[:pesticide_application_detail_attributes]
        ad_hash = if ad_param.respond_to?(:to_unsafe_h)
                    ad_param.to_unsafe_h.deep_symbolize_keys
                  else
                    ad_param.to_h.symbolize_keys
                  end
        base = @pesticide_application_detail&.to_nested_attributes || {}
        @pesticide_application_detail = PesticideApplicationDetailMasterForm.from_attrs(base.merge(ad_hash))
      end
    end

    def id=(v)
      @id = v
    end

    def persisted?
      !new_record?
    end

    def new_record?
      return @_new_record if defined?(@_new_record)

      @id.blank?
    end

    def to_param
      id.present? ? id.to_s : ""
    end

    def is_reference?
      Domain::Shared::TypeConverters::BooleanConverter.cast(is_reference)
    end

    def to_ar_nested_attributes
      {
        name: name,
        active_ingredient: active_ingredient,
        description: description,
        crop_id: crop_id,
        pest_id: pest_id,
        is_reference: Domain::Shared::TypeConverters::BooleanConverter.cast(is_reference),
        region: region,
        user_id: user_id,
        pesticide_usage_constraint_attributes: @pesticide_usage_constraint.to_nested_attributes,
        pesticide_application_detail_attributes: @pesticide_application_detail.to_nested_attributes
      }
    end

    def reload_from_snapshot!(snapshot)
      fresh = self.class.from_snapshot(snapshot)
      %i[
        @id @_new_record @pesticide_usage_constraint @pesticide_application_detail
        @name @active_ingredient @description @crop_id @pest_id @is_reference @region @user_id
      ].each do |iv|
        instance_variable_set(iv, fresh.instance_variable_get(iv))
      end
      errors.clear
      snapshot.error_messages.each { |msg| errors.add(:base, msg) }
      self
    end
  end
end
