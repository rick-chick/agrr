# frozen_string_literal: true

module DeletionUndo
  class SnapshotRestorer
    def initialize(snapshot)
      @snapshot = snapshot.deep_dup
    end

    def restore!
      restore_node(@snapshot)
    end

    private

    def restore_node(node, parent: nil, reflection: nil)
      raise ArgumentError, 'snapshot node must be present' if node.blank?

      klass = node.fetch('model').constantize
      attributes = node.fetch('attributes').dup
      associations = node.fetch('associations', {})
      primary_key = klass.primary_key.to_s

      record = build_record(klass, parent, reflection)

      if attributes.key?(primary_key)
        record.public_send("#{primary_key}=", attributes.delete(primary_key))
      end

      record.assign_attributes(attributes)
      save_record(record)

      associations.each do |name, child_snapshot|
        restore_association(record, name, child_snapshot)
      end

      record
    end

    def build_record(klass, parent, reflection)
      if parent.nil? || reflection.nil?
        klass.new
      elsif reflection.collection?
        parent.public_send(reflection.name).build
      elsif reflection.macro == :has_one
        parent.public_send("build_#{reflection.name}")
      else
        klass.new
      end
    end

    def save_record(record)
      record.save!(validate: false)
    end

    def restore_association(record, name, snapshot)
      reflection = record.class.reflect_on_association(name.to_sym)
      return unless reflection

      if reflection.collection?
        Array(snapshot).each do |child|
          restore_node(child, parent: record, reflection: reflection)
        end
      else
        restore_node(snapshot, parent: record, reflection: reflection)
      end
    end
  end
end

