# frozen_string_literal: true

module Forms
  # 肥料マスタ HTML 用（ActiveRecord をビューに渡さない）。param キーは `fertilize`。
  class FertilizeMasterForm
    include Forms::HtmlFormSupport

    # +user_id+ はフォームに出さないが、AR 検証（ユーザー必須など）のためにスナップショットから引き継ぐ。
    ATTR_KEYS = %i[name n p k description package_size is_reference region user_id].freeze

    attr_accessor(*ATTR_KEYS)
    attr_reader :id

    def self.model_name
      Domain::Shared::FormModelName.from_logical_name("Fertilize")
    end

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

    def apply_params!(params_hash)
      h = params_hash.to_h.symbolize_keys
      ATTR_KEYS.each { |k| send("#{k}=", h[k]) if h.key?(k) }
    end

    def to_ar_attributes
      {
        name: name,
        n: n,
        p: p,
        k: k,
        description: description,
        package_size: package_size,
        is_reference: is_reference,
        region: region,
        user_id: user_id
      }.compact
    end
  end
end
