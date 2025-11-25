# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class InteractionRulesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          @user.generate_api_key!
          @api_key = @user.api_key
        end

        test "should get index" do
          rule1 = create(:interaction_rule, :user_owned, user: @user)
          rule2 = create(:interaction_rule, :user_owned, user: @user)
          # 参照ルールは含まれない
          reference_rule = create(:interaction_rule, :reference)
          # 他のユーザーのルールは含まれない
          other_user = create(:user)
          other_rule = create(:interaction_rule, :user_owned, user: other_user)

          get api_v1_masters_interaction_rules_path, 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 2, json_response.length
          rule_ids = json_response.map { |r| r["id"] }
          assert_includes rule_ids, rule1.id
          assert_includes rule_ids, rule2.id
          assert_not_includes rule_ids, reference_rule.id
          assert_not_includes rule_ids, other_rule.id
        end

        test "should show interaction_rule" do
          rule = create(:interaction_rule, :user_owned, user: @user, source_group: "テストグループ")

          get api_v1_masters_interaction_rule_path(rule), 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal rule.id, json_response["id"]
          assert_equal "テストグループ", json_response["source_group"]
        end

        test "should create interaction_rule" do
          assert_difference("@user.interaction_rules.where(is_reference: false).count", 1) do
            post api_v1_masters_interaction_rules_path, 
                 params: { 
                   interaction_rule: {
                     rule_type: "continuous_cultivation",
                     source_group: "ソースグループ",
                     target_group: "ターゲットグループ",
                     impact_ratio: 0.7
                   }
                 },
                 headers: { 
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          end

          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal "ソースグループ", json_response["source_group"]
          assert_equal @user.id, json_response["user_id"]
          assert_equal false, json_response["is_reference"]
        end

        test "should update interaction_rule" do
          rule = create(:interaction_rule, :user_owned, user: @user, source_group: "元のグループ")

          patch api_v1_masters_interaction_rule_path(rule), 
                params: { 
                  interaction_rule: {
                    source_group: "更新されたグループ"
                  }
                },
                headers: { 
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal "更新されたグループ", json_response["source_group"]
        end

        test "should destroy interaction_rule" do
          rule = create(:interaction_rule, :user_owned, user: @user)

          assert_difference("@user.interaction_rules.where(is_reference: false).count", -1) do
            delete api_v1_masters_interaction_rule_path(rule), 
                   headers: { 
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :no_content
        end
      end
    end
  end
end
