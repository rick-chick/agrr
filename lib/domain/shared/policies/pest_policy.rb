# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class PestPolicy
        def self.view_allowed?(user, is_reference:, user_id:)
          is_reference || user_id == user.id
        end

        def self.edit_allowed?(user, is_reference:, user_id:)
          if user.admin?
            is_reference || user_id == user.id
          else
            !is_reference && user_id == user.id
          end
        end

        def self.normalize_attrs_for_create(user, attrs, admin_forced: false)
          h = attrs.to_h.symbolize_keys
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(h[:is_reference]) || false

          if user.admin? || admin_forced
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
          pest = current_attrs.to_h.symbolize_keys
          attributes = requested_attrs.to_h.symbolize_keys

          if attributes.key?(:is_reference)
            requested_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(attributes[:is_reference]) || false
            reference_changed = requested_reference != pest[:is_reference]

            if reference_changed
              if requested_reference
                attributes[:user_id] = nil
              else
                attributes[:user_id] = user.id
              end
            end
          end

          attributes
        end
      end
    end
  end
end
