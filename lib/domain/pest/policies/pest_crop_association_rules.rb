# frozen_string_literal: true

module Domain
  module Pest
    module Policies
      # ORM なし。永続スコープ写像は Adapters::Pest::Persistence::PestCropAssociationScopes。
      module PestCropAssociationRules
        module_function

        # @param pest_region [String, nil] 害虫に地域があれば作物も同一地域のみ
        def crop_accessible_for_pest?(
          crop_is_reference:,
          crop_user_id:,
          crop_region:,
          pest_is_reference:,
          pest_user_id:,
          pest_region:,
          actor_user_id:
        )
          if Domain::Shared.present?(pest_region)
            return false if crop_region.to_s != pest_region.to_s
          end

          if pest_is_reference
            return crop_is_reference == true
          end

          owner_id = pest_user_id || actor_user_id
          crop_user_id.to_i == owner_id.to_i && crop_is_reference == false
        end
      end
    end
  end
end
