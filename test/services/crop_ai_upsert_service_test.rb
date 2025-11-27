# frozen_string_literal: true

require 'test_helper'

class CropAiUpsertServiceTest < ActiveSupport::TestCase
  FakeResult = Struct.new(:success?, :data, :error)

  class FakeCreateInteractor
    attr_reader :received_attrs

    def initialize(result)
      @result = result
    end

    def call(attrs)
      @received_attrs = attrs
      @result
    end
  end

  setup do
    @user = create(:user)
  end

  test "creates new crop when no existing crop and agrr returns valid data" do
    crop_info = {
      'success' => true,
      'crop' => {
        'crop_id' => nil,
        'name' => 'ブロッコリー',
        'variety' => 'スプラウト',
        'area_per_unit' => 10.0,
        'revenue_per_area' => 2000.0,
        'groups' => ['leafy']
      },
      'stage_requirements' => []
    }

    created_crop = create(:crop, user: @user, is_reference: false)
    interactor_result = FakeResult.new(true, created_crop, nil)
    fake_interactor = FakeCreateInteractor.new(interactor_result)

    service = CropAiUpsertService.new(
      user: @user,
      create_interactor: fake_interactor
    )

    result = service.call(crop_name: 'ブロッコリー', variety: 'スプラウト', crop_info: crop_info)

    assert result.success?
    assert_equal :created, result.status
    assert_equal true, result.body[:success]
    assert_equal created_crop.id, result.body[:crop_id]
    assert_equal created_crop.name, result.body[:crop_name]

    attrs = fake_interactor.received_attrs
    assert_equal 'ブロッコリー', attrs[:name]
    assert_equal 'スプラウト', attrs[:variety]
    assert_equal 10.0, attrs[:area_per_unit]
    assert_equal 2000.0, attrs[:revenue_per_area]
    assert_equal ['leafy'], attrs[:groups]
    assert_equal @user.id, attrs[:user_id]
    assert_equal false, attrs[:is_reference]
  end

  test "updates existing crop when crop_id is editable by user" do
    existing_crop = create(:crop,
                           user: @user,
                           is_reference: false,
                           name: 'ブロッコリー',
                           variety: '旧品種',
                           area_per_unit: 5.0,
                           revenue_per_area: 1000.0,
                           groups: [])

    crop_info = {
      'success' => true,
      'crop' => {
        'crop_id' => existing_crop.id,
        'name' => 'ブロッコリー',
        'variety' => '新しい品種',
        'area_per_unit' => 20.0,
        'revenue_per_area' => 3000.0,
        'groups' => ['leafy', 'ai']
      },
      'stage_requirements' => []
    }

    fake_interactor = FakeCreateInteractor.new(nil)

    service = CropAiUpsertService.new(
      user: @user,
      create_interactor: fake_interactor
    )

    result = service.call(crop_name: 'ブロッコリー', variety: '上書き品種', crop_info: crop_info)

    assert result.success?
    assert_equal :ok, result.status
    assert_equal true, result.body[:success]
    assert_equal existing_crop.id, result.body[:crop_id]
    assert_equal '上書き品種', result.body[:variety]

    existing_crop.reload
    assert_equal '上書き品種', existing_crop.variety
    assert_equal 20.0, existing_crop.area_per_unit
    assert_equal 3000.0, existing_crop.revenue_per_area
    assert_equal ['leafy', 'ai'], existing_crop.groups
  end
end

