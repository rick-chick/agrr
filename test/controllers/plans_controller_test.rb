# frozen_string_literal: true

require 'test_helper'

class PlansControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = create(:user)
  end

  test 'destroy_returns_undo_token_json' do
    sign_in_as @user
    plan = create(:cultivation_plan, user: @user)

    assert_difference -> { CultivationPlan.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete plan_path(plan), as: :json
        assert_response :success
      end
    end

    body = JSON.parse(@response.body)
    %w[undo_token undo_deadline toast_message undo_path auto_hide_after redirect_path resource_dom_id resource].each do |key|
      assert body.key?(key), "JSONレスポンスに#{key}が含まれていません"
      assert body[key].present?, "#{key} が空です"
    end

    undo_token = body.fetch('undo_token')
    event = DeletionUndoEvent.find(undo_token)

    assert_equal 'CultivationPlan', event.resource_type
    assert_equal plan.id.to_s, event.resource_id
    assert event.scheduled?

    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal plans_path(locale: I18n.locale), body.fetch('redirect_path')
    assert_equal dom_id(plan), body.fetch('resource_dom_id')
    assert_equal plan.display_name, body.fetch('resource')
  end

  test 'undo_endpoint_restores_plan' do
    sign_in_as @user
    plan = create(:cultivation_plan, user: @user)

    delete plan_path(plan), as: :json
    assert_response :success

    body = JSON.parse(@response.body)
    undo_token = body.fetch('undo_token')

    assert_not CultivationPlan.exists?(plan.id), '削除後にCultivationPlanが残っています'

    assert_difference -> { CultivationPlan.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = JSON.parse(@response.body)
    assert_equal 'restored', undo_body.fetch('status')
    assert_equal undo_token, undo_body.fetch('undo_token')

    restored_event = DeletionUndoEvent.find(undo_token)
    assert restored_event.restored?
    assert CultivationPlan.exists?(plan.id), 'Undo後にCultivationPlanが復元されていません'
  end

  test 'undo_endpoint_restores_plan_with_field_cultivations' do
    sign_in_as @user
    plan = create(:cultivation_plan, user: @user)
    
    # 圃場を作成
    field = create(:cultivation_plan_field, cultivation_plan: plan)
    
    # 作物を作成
    crop = create(:crop, user: @user, is_reference: false)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)
    
    # 作付を作成
    field_cultivation = create(:field_cultivation, 
                               cultivation_plan: plan,
                               cultivation_plan_field: field,
                               cultivation_plan_crop: plan_crop)
    
    field_cultivation_id = field_cultivation.id
    field_id = field.id
    plan_crop_id = plan_crop.id
    
    # 計画を削除
    delete plan_path(plan), as: :json
    assert_response :success

    body = JSON.parse(@response.body)
    undo_token = body.fetch('undo_token')

    # 削除後は存在しないことを確認
    assert_not CultivationPlan.exists?(plan.id), '削除後にCultivationPlanが残っています'
    assert_not FieldCultivation.exists?(field_cultivation_id), '削除後にFieldCultivationが残っています'
    assert_not CultivationPlanField.exists?(field_id), '削除後にCultivationPlanFieldが残っています'
    assert_not CultivationPlanCrop.exists?(plan_crop_id), '削除後にCultivationPlanCropが残っています'

    # 計画を復元
    assert_difference -> { CultivationPlan.count }, +1 do
      assert_difference -> { FieldCultivation.count }, +1 do
        assert_difference -> { CultivationPlanField.count }, +1 do
          assert_difference -> { CultivationPlanCrop.count }, +1 do
            post undo_deletion_path, params: { undo_token: undo_token }, as: :json
            assert_response :success
          end
        end
      end
    end

    undo_body = JSON.parse(@response.body)
    assert_equal 'restored', undo_body.fetch('status')
    assert_equal undo_token, undo_body.fetch('undo_token')

    # 復元後の確認
    restored_event = DeletionUndoEvent.find(undo_token)
    assert restored_event.restored?
    
    # 計画が復元されていることを確認
    restored_plan = CultivationPlan.find(plan.id)
    assert_not_nil restored_plan, 'Undo後にCultivationPlanが復元されていません'
    
    # 作付が復元されていることを確認
    restored_field_cultivation = FieldCultivation.find_by(id: field_cultivation_id)
    assert_not_nil restored_field_cultivation, 'Undo後にFieldCultivationが復元されていません'
    assert_equal plan.id, restored_field_cultivation.cultivation_plan_id, '作付の計画IDが一致していません'
    assert_equal field_id, restored_field_cultivation.cultivation_plan_field_id, '作付の圃場IDが一致していません'
    assert_equal plan_crop_id, restored_field_cultivation.cultivation_plan_crop_id, '作付の作物IDが一致していません'
    
    # 圃場が復元されていることを確認
    restored_field = CultivationPlanField.find_by(id: field_id)
    assert_not_nil restored_field, 'Undo後にCultivationPlanFieldが復元されていません'
    assert_equal plan.id, restored_field.cultivation_plan_id, '圃場の計画IDが一致していません'
    
    # 作物が復元されていることを確認
    restored_plan_crop = CultivationPlanCrop.find_by(id: plan_crop_id)
    assert_not_nil restored_plan_crop, 'Undo後にCultivationPlanCropが復元されていません'
    assert_equal plan.id, restored_plan_crop.cultivation_plan_id, '作物の計画IDが一致していません'
  end

  test 'destroy_via_html_redirects_with_undo_notice' do
    sign_in_as @user
    plan = create(:cultivation_plan, user: @user)
    display_name = plan.display_name

    assert_difference -> { CultivationPlan.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete plan_path(plan) # HTMLリクエスト
        assert_redirected_to plans_path
      end
    end

    expected_notice = I18n.t(
      'deletion_undo.redirect_notice',
      resource: display_name
    )
    assert_equal expected_notice, flash[:notice]
  end

  test 'index displays plans including annual plans' do
    sign_in_as @user
    farm1 = create(:farm, user: @user, name: '農場1')
    farm2 = create(:farm, user: @user, name: '農場2')
    
    # 年度ベースの計画を作成
    plan1 = create(:cultivation_plan, user: @user, farm: farm1, plan_year: 2025)
    # 通年計画を作成
    plan2 = create(:cultivation_plan, :annual_planning, user: @user, farm: farm2)
    
    get plans_path
    assert_response :success
    
    # 両方の計画が表示されることを確認
    assert_select 'a[href=?]', plan_path(plan1)
    assert_select 'a[href=?]', plan_path(plan2)
  end

  test 'index displays annual plan with period in display_name' do
    sign_in_as @user
    farm = create(:farm, user: @user, name: 'テスト農場')
    
    # 通年計画を作成
    plan = create(:cultivation_plan, :annual_planning, 
                 user: @user, 
                 farm: farm,
                 planning_start_date: Date.new(2025, 1, 1),
                 planning_end_date: Date.new(2026, 12, 31))
    
    get plans_path
    assert_response :success
    
    # display_nameメソッドが計画期間を表示することを確認
    display_name = plan.display_name
    assert_match /2025/, display_name
    assert_match /2026/, display_name
  end
end

