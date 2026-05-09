# frozen_string_literal: true

module Domain
  module Shared
    # app/policies/pesticide_association_policy.rb と同一ルール（アダプターは本クラスのみ参照する）。
    class PesticideAssociationAccess
      def self.accessible_crops_scope(user)
        if user.admin?
          ::Crop.where("is_reference = ? OR user_id = ?", true, user.id)
        else
          ::Crop.where(user_id: user.id, is_reference: false)
        end.order(:name)
      end

      def self.accessible_pests_scope(user)
        if user.admin?
          ::Pest.where("is_reference = ? OR user_id = ?", true, user.id)
        else
          ::Pest.where(user_id: user.id, is_reference: false)
        end.order(:name)
      end
    end
  end
end
