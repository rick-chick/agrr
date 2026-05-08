# frozen_string_literal: true

# 作物ステージ配下の単一リソース（*Requirement）REST API の統合テストを定義する。
# 各コントローラは `setup` で @user, @api_key, @crop, @crop_stage を用意し、
# `MastersCropStageRequirementApiTestCases.define(self, config)` を呼ぶ。
module MastersCropStageRequirementApiTestCases
  module_function

  def define(test_class, config)
    c = Config.new(config)

    test_class.class_eval do
      define_method(:requirement_api_headers) do
        {
          "Accept" => "application/json",
          "X-API-Key" => @api_key
        }
      end

      test "should show #{c.resource_label}" do
        requirement = create(c.factory, crop_stage: @crop_stage, **c.show_factory_attrs)
        get c.path.call(self, @crop, @crop_stage), headers: requirement_api_headers

        assert_response :success
        json = JSON.parse(response.body)
        instance_exec(json, requirement, &c.assert_show_json)
      end

      test "should return not found when #{c.resource_label} does not exist" do
        get c.path.call(self, @crop, @crop_stage), headers: requirement_api_headers

        assert_response :not_found
        json = JSON.parse(response.body)
        assert_equal "#{c.singular_name} not found", json["error"]
      end

      test "should not show #{c.resource_label} for other user's crop" do
        other_user = create(:user)
        other_crop = create(:crop, :user_owned, user: other_user)
        other_crop_stage = create(:crop_stage, crop: other_crop)
        create(c.factory, crop_stage: other_crop_stage)

        get c.path.call(self, other_crop, other_crop_stage), headers: requirement_api_headers

        assert_response :not_found
      end

      test "should create #{c.resource_label}" do
        assert_difference("#{c.model.name}.count", 1) do
          post c.path.call(self, @crop, @crop_stage),
               params: { c.param_key => c.create_params },
               headers: requirement_api_headers
        end

        assert_response :created
        json = JSON.parse(response.body)
        instance_exec(json, &c.assert_create_json)
      end

      test "should not create #{c.resource_label} if already exists" do
        create(c.factory, crop_stage: @crop_stage)

        assert_no_difference("#{c.model.name}.count") do
          post c.path.call(self, @crop, @crop_stage),
               params: { c.param_key => c.duplicate_create_params },
               headers: requirement_api_headers
        end

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)
        assert_equal "#{c.singular_name} already exists", json["error"]
      end

      test "should not create #{c.resource_label} with invalid params" do
        invalid_params = { c.invalid_param_key => c.invalid_param_value }

        assert_no_difference("#{c.model.name}.count") do
          post c.path.call(self, @crop, @crop_stage),
               params: { c.param_key => invalid_params },
               headers: requirement_api_headers
        end

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)
        assert json["errors"].any?
      end

      test "should update #{c.resource_label}" do
        requirement = create(c.factory, crop_stage: @crop_stage, **c.update_factory_attrs)

        patch c.path.call(self, @crop, @crop_stage),
              params: { c.param_key => c.update_params },
              headers: requirement_api_headers

        assert_response :success
        json = JSON.parse(response.body)
        instance_exec(json, &c.assert_update_json)
        instance_exec(requirement, &c.assert_update_persisted)
      end

      test "should not update #{c.resource_label} if not found" do
        patch c.path.call(self, @crop, @crop_stage),
              params: { c.param_key => c.update_not_found_params },
              headers: requirement_api_headers

        assert_response :not_found
        json = JSON.parse(response.body)
        assert_equal "#{c.singular_name} not found", json["error"]
      end

      test "should not update #{c.resource_label} for other user's crop" do
        other_user = create(:user)
        other_crop = create(:crop, :user_owned, user: other_user)
        other_crop_stage = create(:crop_stage, crop: other_crop)
        requirement = create(c.factory, crop_stage: other_crop_stage, **c.other_user_factory_attrs)

        patch c.path.call(self, other_crop, other_crop_stage),
              params: { c.param_key => c.other_user_update_params },
              headers: requirement_api_headers

        assert_response :not_found
        instance_exec(requirement, &c.assert_other_user_unchanged)
      end

      test "should destroy #{c.resource_label}" do
        create(c.factory, crop_stage: @crop_stage)

        assert_difference("#{c.model.name}.count", -1) do
          delete c.path.call(self, @crop, @crop_stage), headers: requirement_api_headers
        end

        assert_response :no_content
      end

      test "should not destroy #{c.resource_label} if not found" do
        delete c.path.call(self, @crop, @crop_stage), headers: requirement_api_headers

        assert_response :not_found
        json = JSON.parse(response.body)
        assert_equal "#{c.singular_name} not found", json["error"]
      end

      test "should not destroy #{c.resource_label} for other user's crop" do
        other_user = create(:user)
        other_crop = create(:crop, :user_owned, user: other_user)
        other_crop_stage = create(:crop_stage, crop: other_crop)
        create(c.factory, crop_stage: other_crop_stage)

        assert_no_difference("#{c.model.name}.count") do
          delete c.path.call(self, other_crop, other_crop_stage), headers: requirement_api_headers
        end

        assert_response :not_found
      end
    end
  end

  # 設定の正規化とデフォルト（update_not_found_params は update_params と同一でよい場合が多い）
  class Config
    attr_reader :resource_label, :model, :factory, :param_key, :singular_name, :path,
                :show_factory_attrs, :assert_show_json,
                :create_params, :assert_create_json, :duplicate_create_params,
                :invalid_param_key, :invalid_param_value,
                :update_factory_attrs, :update_params, :assert_update_json, :assert_update_persisted,
                :update_not_found_params,
                :other_user_factory_attrs, :other_user_update_params, :assert_other_user_unchanged

    def initialize(hash)
      @resource_label = hash.fetch(:resource_label)
      @model = hash.fetch(:model)
      @factory = hash.fetch(:factory)
      @param_key = hash.fetch(:param_key)
      @singular_name = hash.fetch(:singular_name)
      @path = hash.fetch(:path)
      @show_factory_attrs = hash.fetch(:show_factory_attrs)
      @assert_show_json = hash.fetch(:assert_show_json)
      @create_params = hash.fetch(:create_params)
      @assert_create_json = hash.fetch(:assert_create_json)
      @duplicate_create_params = hash.fetch(:duplicate_create_params)
      @invalid_param_key = hash.fetch(:invalid_param_key)
      @invalid_param_value = hash.fetch(:invalid_param_value)
      @update_factory_attrs = hash.fetch(:update_factory_attrs)
      @update_params = hash.fetch(:update_params)
      @assert_update_json = hash.fetch(:assert_update_json)
      @assert_update_persisted = hash.fetch(:assert_update_persisted)
      @update_not_found_params = hash.fetch(:update_not_found_params) { @update_params }
      @other_user_factory_attrs = hash.fetch(:other_user_factory_attrs)
      @other_user_update_params = hash.fetch(:other_user_update_params)
      @assert_other_user_unchanged = hash.fetch(:assert_other_user_unchanged)
    end
  end
end
