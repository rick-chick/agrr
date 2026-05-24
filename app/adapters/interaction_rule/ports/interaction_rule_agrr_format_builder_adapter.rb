# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Ports
      class InteractionRuleAgrrFormatBuilderAdapter
        include Domain::Shared::Ports::InteractionRuleAgrrFormatBuilderPort

        def build_from(entity_or_record)
          Adapters::InteractionRule::Mappers::InteractionRuleAgrrMapper.to_agrr_format(entity_or_record)
        end

        def build_array_from(entities_or_records)
          Adapters::InteractionRule::Mappers::InteractionRuleAgrrMapper.to_agrr_format_array(entities_or_records)
        end
      end
    end
  end
end
