# frozen_string_literal: true

require "ostruct"

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserFertilizeActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanSaveUserFertilizeGateway
        def find_by_user_id_and_source_fertilize_id(user_id:, source_fertilize_id:)
          record = ::Fertilize.find_by(user_id: user_id, source_fertilize_id: source_fertilize_id)
          return nil unless record

          fertilize_duck(record)
        end

        def create(user_id:, attributes:)
          user = ::User.find_by(id: user_id)
          unless user
            raise Domain::Shared::Exceptions::RecordNotFound, "User not found: #{user_id}"
          end

          fertilize = user.fertilizes.build(attributes)
          unless fertilize.save
            raise Domain::Shared::Exceptions::RecordInvalid, fertilize.errors.full_messages.join(", ")
          end

          fertilize_duck(fertilize)
        end

        private

        def fertilize_duck(record)
          ::OpenStruct.new(id: record.id, name: record.name)
        end
      end
    end
  end
end
