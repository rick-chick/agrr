# frozen_string_literal: true

require "test_helper"


class CropDetailApiPresenterTest < ActiveSupport::TestCase
  test "on_success calls view.render_response with ok status and serialized crop" do
    view_mock = Minitest::Mock.new
    presenter = Adapters::Crop::Presenters::CropDetailApiPresenter.new(view: view_mock)

    stage_entity = Struct.new(
      :id,
      :crop_id,
      :name,
      :order,
      :temperature_requirement,
      :thermal_requirement,
      :sunshine_requirement,
      :nutrient_requirement
    ).new(2, 1, "定植", 1, nil, nil, nil, nil)

    crop_entity = Struct.new(
      :id,
      :name,
      :variety,
      :area_per_unit,
      :revenue_per_area,
      :region,
      :groups,
      :user_id,
      :created_at,
      :updated_at,
      :is_reference,
      :crop_stages
    ).new(
      1,
      "トマト",
      "桃太郎",
      10,
      20,
      "kanto",
      [ "A" ],
      9,
      "2026-02-01T00:00:00.000Z",
      "2026-02-02T00:00:00.000Z",
      false,
      [ stage_entity ]
    )

    crop_detail_dto = Struct.new(:crop).new(crop_entity)

    expected_json = {
      id: 1,
      name: "トマト",
      variety: "桃太郎",
      area_per_unit: 10,
      revenue_per_area: 20,
      region: "kanto",
      groups: [ "A" ],
      user_id: 9,
      created_at: "2026-02-01T00:00:00.000Z",
      updated_at: "2026-02-02T00:00:00.000Z",
      is_reference: false,
      crop_stages: [
        {
          id: 2,
          crop_id: 1,
          name: "定植",
          order: 1
        }
      ]
    }

    view_mock.expect(:render_response, nil) do |json:, status:|
      assert_equal :ok, status
      assert_equal expected_json, json
    end

    presenter.on_success(crop_detail_dto)

    view_mock.verify
  end
end
