# frozen_string_literal: true

module Domain
  module Shared
    # ListInteractor の `index_list_filter` と同型の「Policy が組み立て、Gateway は写像のみ」用フィルタ。
    # 参照マスタの単体レコード view/edit 可否および（作物マスタ用）農作業テンプレ紐付け可否を、単一ソースの Policy に委譲する。
    class ReferenceRecordAccessFilter
      attr_reader :user, :policy_module

      def initialize(user:, policy_module:)
        @user = user
        @policy_module = policy_module
      end

      def view_allows?(is_reference:, record_user_id:)
        @policy_module.view_allowed?(@user, is_reference: is_reference, user_id: record_user_id)
      end

      def edit_allows?(is_reference:, record_user_id:)
        @policy_module.edit_allowed?(@user, is_reference: is_reference, user_id: record_user_id)
      end

      # 作物に紐づく CropTaskTemplate 作成時の農作業側可否（AgriculturalTaskPolicy と整合）
      def agricultural_task_template_associate_allows?(is_reference:, record_user_id:)
        Policies::AgriculturalTaskPolicy.masters_crop_task_template_associate_allowed?(
          @user,
          is_reference: is_reference,
          user_id: record_user_id
        )
      end

      def ==(other)
        other.is_a?(ReferenceRecordAccessFilter) &&
          other.user.id == user.id &&
          other.policy_module == policy_module
      end

      alias eql? ==

      def hash
        [ user.id, policy_module ].hash
      end
    end
  end
end
