# frozen_string_literal: true

module Forms
  # 作物配下ネスト害虫 HTML（`form_with` / show）用。`PestCropNestSnapshot` をラップする。
  class CropNestedPestForm
    include ActiveModel::Model

    attr_accessor :id, :user_id, :name, :name_scientific, :family, :order,
                  :description, :occurrence_season, :region, :is_reference,
                  :created_at, :updated_at

    attr_reader :pest_temperature_profile, :pest_thermal_requirement

    def pest_control_methods
      @pest_control_methods
    end

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("Pest")
    end

    def self.from_crop_nest_snapshot(dto)
      raise ArgumentError, "dto required" unless dto

      new.tap { |m| m.apply_crop_nest_snapshot!(dto) }
    end

    def apply_crop_nest_snapshot!(dto)
      self.id = dto.id
      self.user_id = dto.user_id
      self.name = dto.name
      self.name_scientific = dto.name_scientific
      self.family = dto.family
      self.order = dto.order
      self.description = dto.description
      self.occurrence_season = dto.occurrence_season
      self.region = dto.region
      self.is_reference = dto.is_reference
      self.created_at = dto.created_at
      self.updated_at = dto.updated_at

      @pest_temperature_profile = NestedPestTemperatureProfile.from_row(dto.temperature_profile_row)
      @pest_thermal_requirement = NestedPestThermalRequirement.from_row(dto.thermal_requirement_row)
      @pest_control_methods = dto.control_method_rows.map { |row| NestedPestControlMethod.from_row(row) }

      dto.error_messages_by_attribute.each do |attr, msgs|
        Array(msgs).each { |msg| errors.add(attr, msg) }
      end
    end

    def persisted?
      id.present?
    end

    def new_record?
      !persisted?
    end

    def reference?
      Domain::Shared::TypeConverters::BooleanConverter.cast(is_reference)
    end

    alias is_reference? reference?

    # {PestPolicy.normalize_attrs_for_update} 向けの現在状態（作物ネスト編集）
    def to_policy_current_hash
      { is_reference: reference? }
    end

    def to_param
      id&.to_s
    end

    # form の fields_for が nested attributes 経路で子レコードを列挙するために必要（表示再描画のみ）。
    def pest_temperature_profile_attributes=(_attrs); end

    def pest_thermal_requirement_attributes=(_attrs); end

    def pest_control_methods_attributes=(_attrs); end

    class NestedPestTemperatureProfile
      include ActiveModel::Model

      attr_accessor :id, :base_temperature, :max_temperature

      def self.model_name
        Domain::Shared::FormModelName.from_logical_name("PestTemperatureProfile")
      end

      def persisted?
        id.present?
      end

      def new_record?
        !persisted?
      end

      def self.from_row(row)
        return nil if row.blank?

        new.tap do |o|
          o.id = row[:id]
          o.base_temperature = row[:base_temperature]
          o.max_temperature = row[:max_temperature]
        end
      end
    end

    class NestedPestThermalRequirement
      include ActiveModel::Model

      attr_accessor :id, :required_gdd, :first_generation_gdd

      def self.model_name
        Domain::Shared::FormModelName.from_logical_name("PestThermalRequirement")
      end

      def persisted?
        id.present?
      end

      def new_record?
        !persisted?
      end

      def self.from_row(row)
        return nil if row.blank?

        new.tap do |o|
          o.id = row[:id]
          o.required_gdd = row[:required_gdd]
          o.first_generation_gdd = row[:first_generation_gdd]
        end
      end
    end

    class NestedPestControlMethod
      include ActiveModel::Model

      attr_accessor :id, :method_type, :method_name, :description, :timing_hint

      def self.model_name
        Domain::Shared::FormModelName.from_logical_name("PestControlMethod")
      end

      def persisted?
        id.present?
      end

      def new_record?
        !persisted?
      end

      def marked_for_destruction?
        false
      end

      def self.from_row(row)
        new.tap do |o|
          o.id = row[:id]
          o.method_type = row[:method_type]
          o.method_name = row[:method_name]
          o.description = row[:description]
          o.timing_hint = row[:timing_hint]
        end
      end
    end
  end
end
