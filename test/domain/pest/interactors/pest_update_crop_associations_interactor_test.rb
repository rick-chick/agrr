# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class PestUpdateCropAssociationsInteractorTest < DomainLibTestCase
        setup do
          @crop_pest_gateway = mock
          @interactor = PestUpdateCropAssociationsInteractor.new(crop_pest_gateway: @crop_pest_gateway)
        end

        test "replaces associations with add and remove counts" do
          @crop_pest_gateway.expects(:list_by_pest_id).with(pest_id: 5).returns([ 1, 2 ])
          @crop_pest_gateway.expects(:delete).with(crop_id: 1, pest_id: 5).returns(true)
          @crop_pest_gateway.expects(:find_by_crop_id_and_pest_id).with(crop_id: 3, pest_id: 5).returns(nil)
          @crop_pest_gateway.expects(:create).with(crop_id: 3, pest_id: 5)

          result = @interactor.call(pest_id: 5, crop_ids: [ 2, 3 ])

          assert_equal 1, result.added
          assert_equal 1, result.removed
        end
      end
    end
  end
end
