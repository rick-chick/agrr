# frozen_string_literal: true

require "test_helper"

module Adapters
  module Crop
    module Gateways
      class CropStageActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = Adapters::Crop::Gateways::CropStageActiveRecordGateway.new
          @crop = create(:crop)
        end

        test "find_by_id returns crop stage entity when record exists" do
          crop_stage = create(:crop_stage, crop: @crop, name: "Seedling", order: 1)

          result = @gateway.find_by_id(crop_stage.id)

          assert_equal crop_stage.id, result.id
          assert_equal "Seedling", result.name
        end

        test "find_by_id raises RecordNotFound when missing" do
          assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
            @gateway.find_by_id(999_999_999)
          end
        end
      end
    end
  end
end
