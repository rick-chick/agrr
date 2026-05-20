# frozen_string_literal: true

module Domain
  module InteractionRule
    # マスタフォームで扱う属性キー（Gateway / Mapper / Snapshot で共有）。
    module MasterFormAttributes
      KEYS = %i[
        rule_type
        source_group
        target_group
        impact_ratio
        is_directional
        description
        region
        is_reference
      ].freeze
    end
  end
end
