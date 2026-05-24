# frozen_string_literal: true

module Domain
  module Shared
    # @deprecated Prefer Domain::Shared::Policies::CropPolicy.crop_associable_with_pest?
    class PestCropAssociationAccess
      def self.crop_accessible_for_pest?(crop, pest, user: nil)
        Domain::Shared::Policies::CropPolicy.crop_associable_with_pest?(
          user: user,
          crop_is_reference: reference?(crop),
          crop_user_id: crop.user_id,
          crop_region: crop.region,
          pest_is_reference: reference?(pest),
          pest_user_id: pest.user_id,
          pest_region: pest.region
        )
      end

      def self.reference?(record)
        return record.reference? if record.respond_to?(:reference?)
        return record.is_reference? if record.respond_to?(:is_reference?)

        !!record.is_reference
      end
      private_class_method :reference?
    end
  end
end
