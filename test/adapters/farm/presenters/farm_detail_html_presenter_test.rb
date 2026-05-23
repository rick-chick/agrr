# frozen_string_literal: true

require "test_helper"

module Adapters
  module Farm
    module Presenters
      class FarmDetailHtmlPresenterTest < ActiveSupport::TestCase
        test "on_success assigns farm, fields, and turbo stream subscription" do
          view = Object.new
          farm = Domain::Farm::Entities::FarmEntity.new(
            id: 7, name: "Farm", latitude: nil, longitude: nil, region: nil, user_id: 1,
            created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1), is_reference: false
          )
          dto = Domain::Farm::Dtos::FarmDetailOutput.new(farm: farm, fields: [])
          presenter = FarmDetailHtmlPresenter.new(view: view)

          presenter.on_success(dto)

          assert_equal farm, view.instance_variable_get(:@farm)
          assert_equal [], view.instance_variable_get(:@fields)
          assert_equal Domain::Shared::Dtos::TurboStreamSubscription.for_farm(7),
                       view.instance_variable_get(:@turbo_stream_subscription)
        end
      end
    end
  end
end
