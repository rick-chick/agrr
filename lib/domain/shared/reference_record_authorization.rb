# frozen_string_literal: true

module Domain
  module Shared
    # R0: Policy 評価は Interactor 側。Gateway は find 後に本モジュールで assert する。
    module ReferenceRecordAuthorization
      module_function

      def assert_view_allowed!(access_filter, record)
        unless access_filter.view_allows?(
          is_reference: referencable_is_reference(record),
          record_user_id: referencable_user_id(record)
        )
          raise Domain::Shared::Policies::PolicyPermissionDenied
        end
      end

      def assert_edit_allowed!(access_filter, record)
        unless access_filter.edit_allows?(
          is_reference: referencable_is_reference(record),
          record_user_id: referencable_user_id(record)
        )
          raise Domain::Shared::Policies::PolicyPermissionDenied
        end
      end

      def referencable_is_reference(record)
        if record.respond_to?(:is_reference?)
          record.is_reference?
        elsif record.respond_to?(:is_reference)
          !!record.is_reference
        elsif record.respond_to?(:reference?)
          record.reference?
        else
          raise ArgumentError, "record must respond to is_reference, is_reference?, or reference?"
        end
      end

      def referencable_user_id(record)
        raise ArgumentError, "record must respond to user_id" unless record.respond_to?(:user_id)

        record.user_id
      end
    end
  end
end
