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

    def restore_node(node, parent: nil, reflection: nil, skip_associations: false)
      raise ArgumentError, 'snapshot node must be present' if node.blank?

      klass = node.fetch('model').constantize
      attributes = node.fetch('attributes').dup
      associations = node.fetch('associations', {})
      primary_key = klass.primary_key.to_s

      # 既に保存されているレコードを再利用
      if attributes.key?(primary_key)
        existing_record = klass.find_by(primary_key => attributes[primary_key])
        if existing_record
          record = existing_record
          attributes.delete(primary_key)
        else
          record = build_record(klass, parent, reflection)
          record.public_send("#{primary_key}=", attributes.delete(primary_key))
        end
      else
        record = build_record(klass, parent, reflection)
      end

      record.assign_attributes(attributes)
      save_record(record)

      # skip_associationsがtrueの場合はアソシエーションを復元しない（2段階復元の第1段階）
      return record if skip_associations

      # アソシエーションを復元順序で分類
      # 親レコードに依存しないアソシエーションを先に復元し、
      # その後、親レコードに依存するアソシエーションを復元
      sorted_associations = sort_associations_for_restore(record, associations)

      # 2段階の復元: まず親レコードを復元し、その後子レコードを復元
      first_pass, second_pass = sorted_associations.partition do |name, _snapshot|
        !depends_on_other_associations?(record, name, associations)
      end

      # 第1パス: 親レコードに依存しないアソシエーションを復元（親レコードを保存のみ）
      first_pass_parent_records = []
      first_pass.each do |name, child_snapshot|
        reflection = record.class.reflect_on_association(name.to_sym)
        next unless reflection
        
        if reflection.collection?
          Array(child_snapshot).each do |child|
            first_pass_parent_records << restore_node(child, parent: record, reflection: reflection, skip_associations: true)
          end
        else
          first_pass_parent_records << restore_node(child_snapshot, parent: record, reflection: reflection, skip_associations: true)
        end
      end

      # 第1パスの親レコードがすべて保存された後、第1パスの親レコードのアソシエーションを復元
      first_pass.each do |name, child_snapshot|
        restore_association(record, name, child_snapshot, skip_associations: false)
      end

      # 第2パス: 親レコードに依存するアソシエーションを復元
      second_pass.each do |name, child_snapshot|
        restore_association(record, name, child_snapshot, skip_associations: false)
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

    def restore_association(record, name, snapshot, skip_associations: false)
      reflection = record.class.reflect_on_association(name.to_sym)
      return unless reflection

      if reflection.collection?
        Array(snapshot).each do |child|
          restore_node(child, parent: record, reflection: reflection, skip_associations: skip_associations)
        end
      else
        restore_node(snapshot, parent: record, reflection: reflection, skip_associations: skip_associations)
      end
    end

    # アソシエーションが他のアソシエーションに依存しているか確認
    def depends_on_other_associations?(record, association_name, all_associations)
      reflection = record.class.reflect_on_association(association_name.to_sym)
      return false unless reflection

      child_model = reflection.klass

      # すべてのアソシエーションのクラス名を事前に取得
      association_class_names = {}
      all_associations.each do |name, _snapshot|
        other_reflection = record.class.reflect_on_association(name.to_sym)
        association_class_names[name] = other_reflection&.class_name if other_reflection
      end

      # 子レコードのbelongs_toアソシエーションを確認
      child_model.reflect_on_all_associations(:belongs_to).any? do |belongs_to_ref|
        belongs_to_class_name = belongs_to_ref.class_name
        
        # belongs_toのクラス名が他のアソシエーションのクラス名と一致するか確認
        # ただし、親レコード自身を参照している場合は除外
        if association_class_names.values.include?(belongs_to_class_name) &&
           belongs_to_class_name != record.class.name
          Rails.logger.debug "🔍 [SnapshotRestorer] #{association_name} depends on #{belongs_to_class_name}"
          true
        else
          false
        end
      end
    end

    # アソシエーションを復元順序でソート
    # 親レコードに依存しないアソシエーションを先に復元し、
    # その後、親レコードに依存するアソシエーションを復元
    def sort_associations_for_restore(record, associations)
      return associations.to_a if associations.empty?

      associations.to_a.partition do |name, _snapshot|
        !depends_on_other_associations?(record, name, associations)
      end.flatten(1)
    end
  end
end

