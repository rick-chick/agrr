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

  test "rolls back new crop when stage saving fails" do
    crop_info = {
      'success' => true,
      'crop' => {
        'crop_id' => nil,
        'name' => 'キャベツ',
        'variety' => '春系',
        'area_per_unit' => 5.0,
        'revenue_per_area' => 1500.0,
        'groups' => ['leafy']
      },
      # order が欠落して save_crop_stages 内で ArgumentError を発生させる
      'stage_requirements' => [
        {
          'stage' => {
            'name' => '定植',
            'order' => nil
          }
        }
      ]
    }

    gateway = Adapters::Crop::Gateways::CropMemoryGateway.new
    create_interactor = Adapters::Crop::CropCreateForAiAdapter.new(user_id: @user.id, gateway: gateway)

    service = CropAiUpsertService.new(
      user: @user,
      create_interactor: create_interactor
    )

    result = nil
    assert_no_difference ['Crop.count', 'CropStage.count'] do
      result = service.call(crop_name: 'キャベツ', variety: '春系', crop_info: crop_info)
    end

    assert_not result.success?
    assert_equal :internal_server_error, result.status
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

  test "keeps existing stages when new stage requirements are invalid (should not destroy before validating)" do
    existing_crop = create(:crop,
                           user: @user,
                           is_reference: false,
                           name: 'トマト',
                           variety: '既存品種')
    create(:crop_stage, crop: existing_crop, name: '発芽', order: 0)

    crop_info = {
      'success' => true,
      'crop' => {
        'crop_id' => existing_crop.id,
        'name' => 'トマト',
        'variety' => '更新品種',
        'area_per_unit' => 12.0,
        'revenue_per_area' => 2500.0,
        'groups' => []
      },
      # order が欠落しており、create! が例外を出す想定
      'stage_requirements' => [
        {
          'stage' => {
            'name' => '育苗',
            'order' => nil
          }
        }
      ]
    }

    service = CropAiUpsertService.new(
      user: @user,
      create_interactor: FakeCreateInteractor.new(FakeResult.new(true, existing_crop, nil))
    )

    result = service.call(crop_name: 'トマト', variety: '更新品種', crop_info: crop_info)

    assert_not result.success?
    assert_equal :internal_server_error, result.status

    # ステージ生成に失敗しても既存ステージは残ってほしい（現状はdestroy_all後に例外で消える）
    assert_equal 1, existing_crop.crop_stages.reload.count
    assert_equal ['発芽'], existing_crop.crop_stages.pluck(:name)
  end
end

