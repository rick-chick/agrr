# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class AgriculturalTaskPolicy
        def self.view_allowed?(user, is_reference:, user_id:)
          user.admin? || is_reference || user_id == user.id
        end

        # マスター API: 作物に紐付ける農業タスクは参照タスクまたは自ユーザーのタスクのみ（管理者も他人所有タスクは不可）
        def self.masters_crop_task_template_associate_allowed?(user, is_reference:, user_id:)
          is_reference || user_id == user.id
        end

        def self.edit_allowed?(user, is_reference:, user_id:)
          user.admin? || (!is_reference && user_id == user.id)
        end

        def self.normalize_attrs_for_create(user, attrs)
          h = attrs.to_h.symbolize_keys
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(h[:is_reference]) || false

          if user.admin?
            if is_reference
              h[:user_id] = nil
              h[:is_reference] = true
            else
              h[:user_id] ||= user.id
              h[:is_reference] = false
            end
          else
            h[:user_id] = user.id
            h[:is_reference] = false
          end

          h
        end

        def self.normalize_attrs_for_update(user, current_attrs, requested_attrs)
          task = current_attrs.to_h.symbolize_keys
          attributes = requested_attrs.to_h.symbolize_keys

          if attributes.key?(:is_reference)
            requested_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(attributes[:is_reference])
            requested_reference = false if requested_reference.nil?

            reference_changed = requested_reference != task[:is_reference]

            if reference_changed
              if requested_reference
                attributes[:user_id] = nil
              else
                attributes[:user_id] = user.id
              end

              attributes[:is_reference] = requested_reference
            else
              attributes.delete(:is_reference)
            end
          end

          attributes
        end
      end
    end
  end
end
