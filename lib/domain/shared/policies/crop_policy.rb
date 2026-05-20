# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class CropPolicy
        def self.view_allowed?(user, is_reference:, user_id:)
          user.admin? || is_reference || user_id == user.id
        end

        def self.edit_allowed?(user, is_reference:, user_id:)
          user.admin? || (!is_reference && user_id == user.id)
        end

        # @return [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def self.index_list_filter(user)
          mode = user.admin? ? :reference_or_owned : :owned_non_reference
          Domain::Shared::ValueObjects::ReferenceIndexListFilter.new(mode: mode, user_id: user.id)
        end

        def self.record_access_filter(user)
          Domain::Shared::ReferenceRecordAccessFilter.new(user: user, policy_module: self)
        end

        def self.normalize_attrs_for_create(user, attrs)
          h = Domain::Shared.symbolize_keys(attrs.to_h)
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

        # current_attrs: { is_reference:, user_id:, ... } スナップショット
        def self.normalize_attrs_for_update(user, current_attrs, requested_attrs)
          crop = Domain::Shared.symbolize_keys(current_attrs.to_h)
          attributes = Domain::Shared.symbolize_keys(requested_attrs.to_h)

          if attributes.key?(:is_reference)
            requested_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(attributes[:is_reference])
            requested_reference = false if requested_reference.nil?

            reference_changed = requested_reference != crop[:is_reference]

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
