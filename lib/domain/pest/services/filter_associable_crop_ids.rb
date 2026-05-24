# frozen_string_literal: true

module Domain
  module Pest
    module Services
      class FilterAssociableCropIds
        def self.for_pest_update(crop_ids:, pest:, user:, crop_gateway:)
          filter(
            crop_ids: crop_ids,
            user: user,
            crop_gateway: crop_gateway,
            pest_is_reference: pest.reference?,
            pest_user_id: pest.user_id,
            pest_region: pest.region,
            linkable: ->(user:, crop_is_reference:, crop_user_id:, crop_region:, pest_is_reference:, pest_user_id:, pest_region:) {
              Domain::Shared::Policies::CropPolicy.crop_associable_with_pest?(
                user: user,
                crop_is_reference: crop_is_reference,
                crop_user_id: crop_user_id,
                crop_region: crop_region,
                pest_is_reference: pest_is_reference,
                pest_user_id: pest_user_id,
                pest_region: pest_region
              )
            }
          )
        end

        def self.for_ai_affected_crops(crop_ids:, pest:, user:, crop_gateway:)
          filter(
            crop_ids: crop_ids,
            user: user,
            crop_gateway: crop_gateway,
            pest_is_reference: pest.reference?,
            pest_user_id: pest.user_id,
            pest_region: pest.region,
            linkable: ->(user:, crop_is_reference:, crop_user_id:, crop_region:, pest_is_reference:, pest_user_id:, pest_region:) {
              Domain::Shared::Policies::CropPolicy.ai_affected_crop_linkable?(
                user: user,
                crop_is_reference: crop_is_reference,
                crop_user_id: crop_user_id,
                crop_region: crop_region,
                pest_is_reference: pest_is_reference,
                pest_user_id: pest_user_id,
                pest_region: pest_region
              )
            }
          )
        end

        def self.filter(crop_ids:, user:, crop_gateway:, pest_is_reference:, pest_user_id:, pest_region:, linkable:)
          Array(crop_ids).filter_map do |crop_id|
            crop = crop_gateway.find_by_id(crop_id)
            next unless linkable.call(
              user: user,
              crop_is_reference: crop.reference?,
              crop_user_id: crop.user_id,
              crop_region: crop.region,
              pest_is_reference: pest_is_reference,
              pest_user_id: pest_user_id,
              pest_region: pest_region
            )

            crop.id
          rescue Domain::Shared::Exceptions::RecordNotFound
            nil
          end.uniq
        end
        private_class_method :filter
      end
    end
  end
end
