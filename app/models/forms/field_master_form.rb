# frozen_string_literal: true

module Forms
  # 圃場マスタ HTML 用（ActiveRecord をビューに渡さない）。param キーは `field`。
  class FieldMasterForm
    include Forms::HtmlFormSupport

    ATTR_KEYS = %i[name area daily_fixed_cost region farm_id user_id].freeze

    attr_accessor(*ATTR_KEYS)
    attr_reader :id

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("Field")
    end

    # @param snapshot [Domain::Farm::Dtos::FieldMasterFormSnapshot]
    # @return [Forms::FieldMasterForm]
    def self.from_snapshot(snapshot)
      obj = new
      snapshot.attributes.each do |key, value|
        key_sym = key.to_sym
        next unless ATTR_KEYS.include?(key_sym)

        obj.send("#{key_sym}=", value)
      end
      obj.instance_variable_set(:@id, snapshot.id)
      obj.instance_variable_set(:@_new_record, snapshot.new_record?)
      snapshot.error_messages.each { |msg| obj.errors.add(:base, msg) }
      obj
    end

    # ブレッドクラム・リンク文言用（+Field+ モデルのインスタンスメソッド +display_name+ に近い表記）。
    #
    # @return [String]
    def display_name
      name.presence || "Field #{id}"
    end

    def id=(v)
      @id = v
    end

    def to_param
      id&.to_s
    end

    def persisted?
      !new_record?
    end

    def new_record?
      return @_new_record if defined?(@_new_record)

      @id.blank?
    end

    def apply_params!(params_hash)
      h = params_hash.to_h.symbolize_keys
      ATTR_KEYS.each { |k| send("#{k}=", h[k]) if h.key?(k) }
    end

    def to_ar_attributes
      {
        name: name,
        area: area,
        daily_fixed_cost: daily_fixed_cost,
        region: region,
        farm_id: farm_id,
        user_id: user_id
      }.compact
    end
  end
end
