# frozen_string_literal: true

require "test_helper"

class Adapters::Fertilize::Gateways::FertilizeActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::Fertilize::Gateways::FertilizeActiveRecordGateway.new(
      deletion_undo_gateway: CompositionRoot.deletion_undo_gateway,
      translator: CompositionRoot.translator
    )
  end

  test "build_blank_fertilize_for_master_form returns new unsaved fertilize" do
    fertilize = @gateway.build_blank_fertilize_for_master_form

    assert_instance_of ::Fertilize, fertilize
    assert fertilize.new_record?
  end
end
