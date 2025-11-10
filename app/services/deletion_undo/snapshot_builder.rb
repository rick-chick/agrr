# frozen_string_literal: true

require 'set'

module DeletionUndo
  class SnapshotBuilder
    attr_reader :record

    def initialize(record, visited: Set.new)
      @record = record
      @visited = visited
    end

    def build
      raise ArgumentError, 'record must be present' if record.nil?

      key = cache_key_for(record)
      return reference_snapshot(record) if @visited.include?(key)

      @visited.add(key)

      {
        'model' => record.class.name,
        'attributes' => serialize_attributes(record),
        'associations' => build_associations(record)
      }
    end

    private

    def cache_key_for(rec)
      [rec.class.name, rec.id]
    end

    def reference_snapshot(rec)
      {
        'model' => rec.class.name,
        'attributes' => { rec.class.primary_key => rec.id },
        'associations' => {},
        'reference' => true
      }
    end

    def serialize_attributes(rec)
      rec.attributes.transform_keys(&:to_s).transform_values { |value| serialize_value(value) }
    end

    def build_associations(rec)
      dependent_associations(rec).each_with_object({}) do |reflection, memo|
        associated = rec.public_send(reflection.name)
        next if associated.blank?

        memo[reflection.name.to_s] = if reflection.collection?
          associated.map { |child| self.class.new(child, visited: @visited).build }
        else
          self.class.new(associated, visited: @visited).build
        end
      end
    end

    def dependent_associations(rec)
      rec.class.reflect_on_all_associations.select do |reflection|
        next false if reflection.options[:polymorphic]
        next false if reflection.macro == :belongs_to

        dependency = reflection.options[:dependent]
        dependency.in?([:destroy, :delete_all])
      end
    end

    def serialize_value(value)
      case value
      when ActiveSupport::TimeWithZone
        value.iso8601(6)
      when Time
        value.utc.iso8601(6)
      when Date
        value.iso8601
      when BigDecimal
        value.to_s
      else
        value
      end
    end
  end
end

