# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Mappers
      class InteractionRuleAgrrMapper
        def self.to_agrr_format(entity_or_record)
          record = entity_or_record
          id = record.respond_to?(:id) ? record.id : record[:id]
          {
            "rule_id" => "rule_#{id}",
            "rule_type" => fetch_attr(record, :rule_type),
            "source_group" => fetch_attr(record, :source_group),
            "target_group" => fetch_attr(record, :target_group),
            "impact_ratio" => fetch_attr(record, :impact_ratio).to_f,
            "is_directional" => fetch_attr(record, :is_directional),
            "description" => fetch_attr(record, :description)
          }.compact
        end

        def self.to_agrr_format_array(entities_or_records)
          Array(entities_or_records).map { |r| to_agrr_format(r) }
        end

        def self.fetch_attr(record, key)
          if record.respond_to?(key)
            record.public_send(key)
          else
            record[key] || record[key.to_s]
          end
        end

        private_class_method :fetch_attr
      end
    end
  end
end
