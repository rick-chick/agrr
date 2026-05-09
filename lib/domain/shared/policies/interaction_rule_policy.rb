# frozen_string_literal: true

module Domain
  module Shared
    module Policies
      class InteractionRulePolicy
        def self.view_allowed?(user, is_reference:, user_id:)
          user.admin? || user_id == user.id
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

        def self.normalize_attrs_for_create(user, params)
          attributes = params.to_h.symbolize_keys
          attributes.delete(:region) unless user.admin?

          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(attributes[:is_reference]) || false

          if is_reference
            attributes[:user_id] = nil
            attributes[:is_reference] = true
          else
            attributes[:user_id] ||= user.id
            attributes[:is_reference] = false if attributes[:is_reference].nil?
          end

          attributes
        end

        def self.normalize_attrs_for_update(user, current_attrs, params)
          rule = current_attrs.to_h.symbolize_keys
          update_params = params.to_h.symbolize_keys

          update_params.delete(:region) unless user.admin?

          if update_params.key?(:is_reference)
            requested_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(update_params[:is_reference]) || false
            reference_changed = requested_reference != rule[:is_reference]

            if reference_changed
              if requested_reference
                update_params[:user_id] = nil
              else
                update_params[:user_id] = user.id
              end
            end
          end

          update_params
        end
      end
    end
  end
end
