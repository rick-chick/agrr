# frozen_string_literal: true

module Adapters
  module Shared
    module Concerns
      # ReferenceIndexListFilter を AR Relation に写すのみ（Policy 判断は domain 側）。
      module ReferenceIndexListFilterRelation
        module_function

        def apply(model_class, filter)
          case filter.mode
          when :reference_or_owned
            model_class.where("is_reference = ? OR user_id = ?", true, filter.user_id)
          when :owned_non_reference
            model_class.where(user_id: filter.user_id, is_reference: false)
          else
            raise ArgumentError, "unknown ReferenceIndexListFilter mode: #{filter.mode.inspect}"
          end
        end
      end
    end
  end
end
