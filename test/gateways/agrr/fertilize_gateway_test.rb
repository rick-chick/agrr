require 'test_helper'

class AgrrFertilizeGatewayTest < ActiveSupport::TestCase
  class StubAgrrService
    attr_reader :received_args
    attr_accessor :response

    def initialize
      @response = {
        'schedule' => [
          { 'task_id' => '1', 'stage_order' => 0, 'stage_name' => '何か', 'gdd_trigger' => 0 }
        ]
      }.to_json
    end

    def fertilize_plan(crop_file:, use_harvest_start:, max_applications:, json:)
      @received_args = {
        crop_file: crop_file,
        use_harvest_start: use_harvest_start,
        max_applications: max_applications,
        json: json
      }
      response
    end
  end

  def setup
    @gateway = Agrr::FertilizeGateway.new
    @stub_service = StubAgrrService.new
    @gateway.instance_variable_set(:@agrr_service, @stub_service)

    @crop = create(:crop, :with_stages, name: 'トマト', variety: '一般')
  end

  test 'plan delegates to agrr service with default max_applications 2' do
    result = @gateway.plan(crop: @crop)

    assert_not_nil result
    assert_not_nil @stub_service.received_args
    assert_equal 2, @stub_service.received_args[:max_applications]
    assert @stub_service.received_args[:json]
  end

  test 'plan allows overriding max_applications' do
    result = @gateway.plan(crop: @crop, max_applications: 1)

    assert_not_nil result
    assert_equal 1, @stub_service.received_args[:max_applications]
  end
end


