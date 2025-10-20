# frozen_string_literal: true

require "test_helper"

class InteractionRulesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
    @interaction_rule = InteractionRule.create!(
      user_id: @user.id,
      rule_type: 'continuous',
      source_group: 'Solanaceae',
      target_group: 'Solanaceae',
      impact_ratio: 0.7,
      is_directional: true,
      description: 'テストルール'
    )
  end

  test "should get new when authenticated" do
    get new_interaction_rule_path
    assert_response :success
    assert_select "h1", "新しいルール作成"
    assert_select "form"
  end

  test "should display new page in Japanese" do
    get new_interaction_rule_path, headers: { 'Accept-Language': 'ja' }
    assert_response :success
    assert_select "h1", "新しいルール作成"
  end

  test "should display new page in English" do
    get new_interaction_rule_path(locale: 'us')
    assert_response :success
    assert_select "h1", "Create New Rule"
  end

  test "should display new page in Hindi" do
    get new_interaction_rule_path(locale: 'in')
    assert_response :success
    assert_select "h1", "नया नियम बनाएं"
  end

  test "should redirect to login when not authenticated for new" do
    delete auth_logout_path
    get new_interaction_rule_path
    assert_redirected_to auth_login_path
  end

  test "should get index when authenticated" do
    get interaction_rules_path
    assert_response :success
  end

  test "should create interaction rule with valid attributes" do
    assert_difference('InteractionRule.count') do
      post interaction_rules_path, params: {
        interaction_rule: {
          rule_type: 'continuous',
          source_group: 'Cucurbitaceae',
          target_group: 'Cucurbitaceae',
          impact_ratio: 0.8,
          is_directional: false,
          description: '新しいルール'
        }
      }
    end
    
    assert_redirected_to interaction_rule_path(InteractionRule.last)
  end

  test "should get show when authenticated and rule belongs to user" do
    get interaction_rule_path(@interaction_rule)
    assert_response :success
  end

  test "should get edit when authenticated and rule belongs to user" do
    get edit_interaction_rule_path(@interaction_rule)
    assert_response :success
  end

  test "should update interaction rule with valid attributes" do
    patch interaction_rule_path(@interaction_rule), params: {
      interaction_rule: {
        impact_ratio: 0.6,
        description: '更新されたルール'
      }
    }
    
    assert_redirected_to interaction_rule_path(@interaction_rule)
    @interaction_rule.reload
    assert_equal 0.6, @interaction_rule.impact_ratio
    assert_equal '更新されたルール', @interaction_rule.description
  end

  test "should destroy interaction rule when authenticated and rule belongs to user" do
    assert_difference('InteractionRule.count', -1) do
      delete interaction_rule_path(@interaction_rule)
    end
    
    assert_redirected_to interaction_rules_path
  end
end

