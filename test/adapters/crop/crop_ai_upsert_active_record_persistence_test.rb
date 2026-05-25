# frozen_string_literal: true

require "test_helper"

module Adapters
  module Crop
    class CropAiUpsertActiveRecordPersistenceTest < ActiveSupport::TestCase
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
        @user_dto = Adapters::Shared::Mappers::UserMapper.user_dto_from_record(@user)
        @crop_access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(@user_dto)
      end

      test "creates new crop when no existing crop and agrr returns valid data" do
        crop_info = {
          "success" => true,
          "crop" => {
            "crop_id" => nil,
            "name" => "ブロッコリー",
            "variety" => "スプラウト",
            "area_per_unit" => 10.0,
            "revenue_per_area" => 2000.0,
            "groups" => [ "leafy" ]
          },
          "stage_requirements" => []
        }

        created_crop = create(:crop, user: @user, is_reference: false)
        interactor_result = FakeResult.new(true, Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(created_crop), nil)
        fake_interactor = FakeCreateInteractor.new(interactor_result)

        persistence = CropAiUpsertActiveRecordPersistence.new(
          crop_gateway: CompositionRoot.crop_gateway,
          create_interactor: fake_interactor,
          logger: CompositionRoot.logger,
          translator: CompositionRoot.translator
        )

        result = persistence.upsert(
          user_dto: @user_dto,
          crop_name: "ブロッコリー",
          variety: "スプラウト",
          crop_info: crop_info,
          crop_access_filter: @crop_access_filter
        )

        assert_instance_of Domain::Crop::Dtos::CropAiCreateOutput, result
        assert_equal :created, result.http_status
        assert result.success
        assert_equal created_crop.id, result.crop_id
        assert_equal created_crop.name, result.crop_name

        attrs = fake_interactor.received_attrs
        assert_equal "ブロッコリー", attrs[:name]
        assert_equal "スプラウト", attrs[:variety]
        assert_equal 10.0, attrs[:area_per_unit]
        assert_equal 2000.0, attrs[:revenue_per_area]
        assert_equal [ "leafy" ], attrs[:groups]
        assert_equal @user.id, attrs[:user_id]
        assert_equal false, attrs[:is_reference]
      end

      test "rolls back new crop when stage saving fails" do
        crop_info = {
          "success" => true,
          "crop" => {
            "crop_id" => nil,
            "name" => "キャベツ",
            "variety" => "春系",
            "area_per_unit" => 5.0,
            "revenue_per_area" => 1500.0,
            "groups" => [ "leafy" ]
          },
          "stage_requirements" => [
            {
              "stage" => {
                "name" => "定植",
                "order" => nil
              }
            }
          ]
        }

        gateway = Adapters::Crop::Gateways::CropActiveRecordGateway.new(
          deletion_undo_gateway: CompositionRoot.deletion_undo_gateway
        )
        create_interactor = Adapters::Crop::CropCreateForAiAdapter.new(
          user_id: @user.id,
          gateway: gateway,
          translator: CompositionRoot.translator,
          user_lookup: CompositionRoot.user_lookup
        )

        persistence = CropAiUpsertActiveRecordPersistence.new(
          crop_gateway: CompositionRoot.crop_gateway,
          create_interactor: create_interactor,
          logger: CompositionRoot.logger,
          translator: CompositionRoot.translator
        )

        result = nil
        assert_no_difference [ "::Crop.count", "::CropStage.count" ] do
          result = persistence.upsert(
            user_dto: @user_dto,
            crop_name: "キャベツ",
            variety: "春系",
            crop_info: crop_info,
            crop_access_filter: @crop_access_filter
          )
        end

        assert_instance_of Domain::Crop::Dtos::CropAiCreateFailure, result
        assert_equal :internal_server_error, result.http_status
      end

      test "updates existing crop when crop_id is editable by user" do
        existing_crop = create(:crop,
                               user: @user,
                               is_reference: false,
                               name: "ブロッコリー",
                               variety: "旧品種",
                               area_per_unit: 5.0,
                               revenue_per_area: 1000.0,
                               groups: [])

        crop_info = {
          "success" => true,
          "crop" => {
            "crop_id" => existing_crop.id,
            "name" => "ブロッコリー",
            "variety" => "新しい品種",
            "area_per_unit" => 20.0,
            "revenue_per_area" => 3000.0,
            "groups" => [ "leafy", "ai" ]
          },
          "stage_requirements" => []
        }

        fake_interactor = FakeCreateInteractor.new(nil)

        persistence = CropAiUpsertActiveRecordPersistence.new(
          crop_gateway: CompositionRoot.crop_gateway,
          create_interactor: fake_interactor,
          logger: CompositionRoot.logger,
          translator: CompositionRoot.translator
        )

        result = persistence.upsert(
          user_dto: @user_dto,
          crop_name: "ブロッコリー",
          variety: "上書き品種",
          crop_info: crop_info,
          crop_access_filter: @crop_access_filter
        )

        assert_instance_of Domain::Crop::Dtos::CropAiCreateOutput, result
        assert_equal :ok, result.http_status
        assert result.success
        assert_equal existing_crop.id, result.crop_id
        assert_equal "上書き品種", result.variety

        existing_crop.reload
        assert_equal "上書き品種", existing_crop.variety
        assert_equal 20.0, existing_crop.area_per_unit
        assert_equal 3000.0, existing_crop.revenue_per_area
        assert_equal [ "leafy", "ai" ], existing_crop.groups
      end

      test "keeps existing stages when new stage requirements are invalid (transaction rolls back)" do
        existing_crop = create(:crop,
                               user: @user,
                               is_reference: false,
                               name: "トマト",
                               variety: "既存品種")
        create(:crop_stage, crop: existing_crop, name: "発芽", order: 0)

        crop_info = {
          "success" => true,
          "crop" => {
            "crop_id" => existing_crop.id,
            "name" => "トマト",
            "variety" => "更新品種",
            "area_per_unit" => 12.0,
            "revenue_per_area" => 2500.0,
            "groups" => []
          },
          "stage_requirements" => [
            {
              "stage" => {
                "name" => "育苗",
                "order" => nil
              }
            }
          ]
        }

        fake_entity = Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(existing_crop)
        fake_interactor = FakeCreateInteractor.new(FakeResult.new(true, fake_entity, nil))

        persistence = CropAiUpsertActiveRecordPersistence.new(
          crop_gateway: CompositionRoot.crop_gateway,
          create_interactor: fake_interactor,
          logger: CompositionRoot.logger,
          translator: CompositionRoot.translator
        )

        result = persistence.upsert(
          user_dto: @user_dto,
          crop_name: "トマト",
          variety: "更新品種",
          crop_info: crop_info,
          crop_access_filter: @crop_access_filter
        )

        assert_instance_of Domain::Crop::Dtos::CropAiCreateFailure, result
        assert_equal :internal_server_error, result.http_status

        assert_equal 1, existing_crop.crop_stages.reload.count
        assert_equal [ "発芽" ], existing_crop.crop_stages.pluck(:name)
      end
    end
  end
end
