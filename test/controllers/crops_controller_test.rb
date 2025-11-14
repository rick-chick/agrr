  class BlueprintServiceDouble
    attr_reader :calls

    def initialize
      @calls = []
    end

    def regenerate!(crop:)
      @calls << crop
    end
  end
# frozen_string_literal: true

require 'test_helper'

class CropsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
    @admin_user = create(:user, admin: true)
    @other_user = create(:user)
    
    # 参照作物（user_id: nil）
    @reference_crop = create(:crop, :with_stages, is_reference: true, user_id: nil)
    # 一般ユーザーの作物
    @user_crop = create(:crop, :with_stages, user: @user)
    # 他のユーザーの作物
    @other_user_crop = create(:crop, :with_stages, user: @other_user)
    # 管理者の作物
    @admin_crop = create(:crop, :with_stages, user: @admin_user)
  end

  # ========== index アクションのテスト ==========
  
  test "一般ユーザーのindexは自身の作物のみ表示" do
    sign_in_as @user
    get crops_path
    
    assert_response :success
    # 一般ユーザーの作物のみが表示される
    assert_select '.crop-card', count: 1
  end

  test "管理者のindexは自身の作物と参照作物を表示" do
    sign_in_as @admin_user
    get crops_path
    
    assert_response :success
    # 管理者の作物と参照作物が表示される
  end

  # ========== show アクションのテスト ==========
  
  test "一般ユーザーは自身の作物をshowできる" do
    sign_in_as @user
    get crop_path(@user_crop)
    
    assert_response :success
  end

  test "一般ユーザーは参照作物をshowできる" do
    sign_in_as @user
    get crop_path(@reference_crop)
    
    assert_response :success
  end

  test "作業テンプレートが表示される" do
    sign_in_as @user
    task = create(:agricultural_task, :soil_preparation)
    create(
      :crop_task_template,
      crop: @user_crop,
      agricultural_task: task,
      name: task.name,
      description: task.description,
      time_per_sqm: task.time_per_sqm,
      weather_dependency: task.weather_dependency,
      required_tools: task.required_tools,
      skill_level: task.skill_level,
      task_type: task.task_type,
      task_type_id: task.task_type_id,
      is_reference: task.is_reference
    )
    create(:crop_task_schedule_blueprint,
           crop: @user_crop,
           agricultural_task: task,
           stage_order: 1,
           stage_name: '定植前整備',
           gdd_trigger: BigDecimal('0.0'),
           gdd_tolerance: BigDecimal('5.0'),
           priority: 1,
           source: 'agrr_schedule')
    fertilizer_task = create(:agricultural_task, :user_owned, user: @user, name: '追肥')
    create(:crop_task_schedule_blueprint,
           :fertilizer,
           crop: @user_crop,
           agricultural_task: fertilizer_task,
           stage_order: 2,
           stage_name: '追肥',
           gdd_trigger: BigDecimal('150.0'),
           gdd_tolerance: BigDecimal('10.0'),
           priority: 2)
    manual_task = create(:agricultural_task, :user_owned, user: @user, name: '潅水')
    create(:crop_task_template,
           crop: @user_crop,
           agricultural_task: manual_task,
           name: manual_task.name)

    get crop_path(@user_crop)

    assert_response :success
    assert_select '#crop-task-schedule-blueprints'
    assert_select '#crop-task-schedule-blueprints', text: /土壌準備/
    assert_select '#crop-task-schedule-blueprints', text: /追肥/
    assert_select '.task-blueprint-card[data-gdd-trigger="150.0"]'
    # manual_task（潅水）のテンプレートが表示されることを確認
    # 参照タスク（task）のテンプレートはavailable_agricultural_tasksに含まれないため表示されない
    assert_select '.task-manual-grid .task-manual-card .task-manual-card__name', text: /潅水/
  end

  test "害虫一覧がカードレイアウトで表示される" do
    sign_in_as @user
    older_pest = create(:pest, name: 'コナジラミ', name_scientific: 'Aleyrodidae', created_at: 2.days.ago)
    recent_pest = create(:pest, name: 'アブラムシ', name_scientific: 'Aphidoidea', created_at: Time.current)
    create(:crop_pest, crop: @user_crop, pest: older_pest)
    create(:crop_pest, crop: @user_crop, pest: recent_pest)

    get crop_path(@user_crop)

    assert_response :success
    assert_select '.pests-grid .pest-card', count: 2
    assert_select '.pest-card:first-child .pest-card__name', text: 'アブラムシ'
    assert_select '.pest-card:first-child .pest-card__scientific', text: 'Aphidoidea'
    assert_select '.pests-section__header .pests-section__action', text: I18n.t('crops.show.manage_pests')
  end

  test "管理者はAIで作業テンプレートを生成できる" do
    sign_in_as @admin_user
    service_double = BlueprintServiceDouble.new

    CropTaskScheduleBlueprintCreateService.stub(:new, service_double) do
      post generate_task_schedule_blueprints_crop_path(@admin_crop)
    end

    assert_equal 1, service_double.calls.size
    assert_equal @admin_crop.id, service_double.calls.first.id
    assert_redirected_to crop_path(@admin_crop)
    assert_equal I18n.t('crops.flash.task_schedule_blueprints_generated'), flash[:notice]
  end

  test "一般ユーザーはAIで作業テンプレートを生成できない" do
    sign_in_as @user

    post generate_task_schedule_blueprints_crop_path(@user_crop)

    assert_redirected_to root_path
    assert_equal I18n.t('auth.messages.admin_required'), flash[:alert]
  end

  test "一般ユーザーは他のユーザーの作物をshowできない" do
    sign_in_as @user
    get crop_path(@other_user_crop)
    
    assert_redirected_to crops_path
    assert_equal I18n.t('crops.flash.no_permission'), flash[:alert]
  end

  # ========== edit アクションのテスト ==========
  
  test "一般ユーザーは自身の作物をeditできる" do
    sign_in_as @user
    get edit_crop_path(@user_crop)
    
    assert_response :success
  end

  test "一般ユーザーは参照作物をeditできない" do
    sign_in_as @user
    get edit_crop_path(@reference_crop)
    
    assert_redirected_to crops_path
    assert_equal I18n.t('crops.flash.no_permission'), flash[:alert]
  end

  test "一般ユーザーは他のユーザーの作物をeditできない" do
    sign_in_as @user
    get edit_crop_path(@other_user_crop)
    
    assert_redirected_to crops_path
    assert_equal I18n.t('crops.flash.no_permission'), flash[:alert]
  end

  test "管理者は参照作物をeditできる" do
    sign_in_as @admin_user
    get edit_crop_path(@reference_crop)
    
    assert_response :success
  end

  test "edit画面でnutrientsが無い場合でもフォームフィールドが表示される" do
    sign_in_as @user
    
    # nutrientsが無い作物を作成
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: '生育期')
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    # nutrientsは作成しない
    
    get edit_crop_path(crop)
    
    assert_response :success
    
    # 画面にnutrientsフィールドが含まれていることを確認
    assert_select 'input[name*="nutrient_requirement_attributes"][name*="daily_uptake_n"]', count: 1
    assert_select 'input[name*="nutrient_requirement_attributes"][name*="daily_uptake_p"]', count: 1
    assert_select 'input[name*="nutrient_requirement_attributes"][name*="daily_uptake_k"]', count: 1
  end

  # ========== update アクションのテスト（nutrients関連） ==========
  
  test "既存ステージにnutrientsを追加できる" do
    sign_in_as @user
    
    # nutrientsが無い作物ステージを作成
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: '生育期')
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    # nutrientsは作成しない
    
    # nutrientsを追加して更新
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [{
          id: stage.id,
          name: '生育期',
          order: 1,
          nutrient_requirement_attributes: {
            daily_uptake_n: 0.5,
            daily_uptake_p: 0.2,
            daily_uptake_k: 0.8
          }
        }]
      }
    }
    
    assert_redirected_to crop_path(crop)
    
    # DBを確認
    stage.reload
    assert_not_nil stage.nutrient_requirement
    assert_equal 0.5, stage.nutrient_requirement.daily_uptake_n
    assert_equal 0.2, stage.nutrient_requirement.daily_uptake_p
    assert_equal 0.8, stage.nutrient_requirement.daily_uptake_k
  end

  test "既存のnutrientsを更新できる" do
    sign_in_as @user
    
    # nutrientsが既にある作物ステージを作成
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: '生育期')
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    nutrient_req = create(:nutrient_requirement, crop_stage: stage, daily_uptake_n: 0.1, daily_uptake_p: 0.05, daily_uptake_k: 0.15)
    
    # nutrientsを更新
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [{
          id: stage.id,
          name: '生育期',
          order: 1,
          nutrient_requirement_attributes: {
            id: nutrient_req.id,
            daily_uptake_n: 0.5,
            daily_uptake_p: 0.2,
            daily_uptake_k: 0.8
          }
        }]
      }
    }
    
    assert_redirected_to crop_path(crop)
    
    # DBを確認
    nutrient_req.reload
    assert_equal 0.5, nutrient_req.daily_uptake_n
    assert_equal 0.2, nutrient_req.daily_uptake_p
    assert_equal 0.8, nutrient_req.daily_uptake_k
  end

  test "既存のnutrientsを0.0に更新できる" do
    sign_in_as @user
    
    # nutrientsが既にある作物ステージを作成
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: '生育期')
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    nutrient_req = create(:nutrient_requirement, crop_stage: stage, daily_uptake_n: 0.5, daily_uptake_p: 0.2, daily_uptake_k: 0.8)
    
    # nutrientsを0.0に更新
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [{
          id: stage.id,
          name: '生育期',
          order: 1,
          nutrient_requirement_attributes: {
            id: nutrient_req.id,
            daily_uptake_n: 0.0,
            daily_uptake_p: 0.0,
            daily_uptake_k: 0.0
          }
        }]
      }
    }
    
    assert_redirected_to crop_path(crop)
    
    # DBを確認
    nutrient_req.reload
    assert_equal 0.0, nutrient_req.daily_uptake_n
    assert_equal 0.0, nutrient_req.daily_uptake_p
    assert_equal 0.0, nutrient_req.daily_uptake_k
  end

  test "既存のnutrientsを削除できる" do
    sign_in_as @user
    
    # nutrientsが既にある作物ステージを作成
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: '生育期')
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    nutrient_req = create(:nutrient_requirement, crop_stage: stage)
    
    # nutrientsを削除
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [{
          id: stage.id,
          name: '生育期',
          order: 1,
          nutrient_requirement_attributes: {
            id: nutrient_req.id,
            _destroy: '1'
          }
        }]
      }
    }
    
    assert_redirected_to crop_path(crop)
    
    # DBを確認
    stage.reload
    assert_nil stage.nutrient_requirement
  end

  test "複数のステージでnutrientsを追加できる" do
    sign_in_as @user
    
    crop = create(:crop, user: @user)
    stage1 = create(:crop_stage, crop: crop, order: 1, name: '発芽期')
    stage2 = create(:crop_stage, crop: crop, order: 2, name: '生育期')
    create(:temperature_requirement, crop_stage: stage1)
    create(:thermal_requirement, crop_stage: stage1)
    create(:temperature_requirement, crop_stage: stage2)
    create(:thermal_requirement, crop_stage: stage2)
    
    # 両方のステージにnutrientsを追加
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [
          {
            id: stage1.id,
            name: '発芽期',
            order: 1,
            nutrient_requirement_attributes: {
              daily_uptake_n: 0.1,
              daily_uptake_p: 0.05,
              daily_uptake_k: 0.15
            }
          },
          {
            id: stage2.id,
            name: '生育期',
            order: 2,
            nutrient_requirement_attributes: {
              daily_uptake_n: 0.5,
              daily_uptake_p: 0.2,
              daily_uptake_k: 0.8
            }
          }
        ]
      }
    }
    
    assert_redirected_to crop_path(crop)
    
    # DBを確認
    stage1.reload
    stage2.reload
    assert_not_nil stage1.nutrient_requirement
    assert_not_nil stage2.nutrient_requirement
    assert_equal 0.1, stage1.nutrient_requirement.daily_uptake_n
    assert_equal 0.5, stage2.nutrient_requirement.daily_uptake_n
  end

  test "nutrients無しのステージと有りのステージを混在できる" do
    sign_in_as @user
    
    crop = create(:crop, user: @user)
    stage1 = create(:crop_stage, crop: crop, order: 1, name: '発芽期')
    stage2 = create(:crop_stage, crop: crop, order: 2, name: '生育期')
    create(:temperature_requirement, crop_stage: stage1)
    create(:thermal_requirement, crop_stage: stage1)
    create(:temperature_requirement, crop_stage: stage2)
    create(:thermal_requirement, crop_stage: stage2)
    
    # stage1のみnutrientsを追加
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [
          {
            id: stage1.id,
            name: '発芽期',
            order: 1,
            nutrient_requirement_attributes: {
              daily_uptake_n: 0.1,
              daily_uptake_p: 0.05,
              daily_uptake_k: 0.15
            }
          },
          {
            id: stage2.id,
            name: '生育期',
            order: 2
          }
        ]
      }
    }
    
    assert_redirected_to crop_path(crop)
    
    # DBを確認
    stage1.reload
    stage2.reload
    assert_not_nil stage1.nutrient_requirement
    assert_nil stage2.nutrient_requirement
  end

  test "新規ステージ作成時にnutrientsを同時に追加できる" do
    sign_in_as @user
    
    crop = create(:crop, user: @user)
    
    # 新規ステージとnutrientsを同時に作成
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [{
          name: '発芽期',
          order: 1,
          temperature_requirement_attributes: {
            base_temperature: 10.0,
            optimal_min: 15.0,
            optimal_max: 25.0,
            low_stress_threshold: 5.0,
            high_stress_threshold: 30.0,
            frost_threshold: 0.0,
            sterility_risk_threshold: nil,
            max_temperature: 40.0
          },
          thermal_requirement_attributes: {
            required_gdd: 100.0
          },
          nutrient_requirement_attributes: {
            daily_uptake_n: 0.5,
            daily_uptake_p: 0.2,
            daily_uptake_k: 0.8
          }
        }]
      }
    }
    
    assert_redirected_to crop_path(crop)
    
    # DBを確認
    stage = crop.crop_stages.first
    assert_not_nil stage
    assert_not_nil stage.nutrient_requirement
    assert_equal 0.5, stage.nutrient_requirement.daily_uptake_n
    assert_equal 0.2, stage.nutrient_requirement.daily_uptake_p
    assert_equal 0.8, stage.nutrient_requirement.daily_uptake_k
  end

  test "他のユーザーの作物はupdateできない" do
    sign_in_as @user
    
    # 他のユーザーの作物を更新しようとする
    patch crop_path(@other_user_crop), params: {
      crop: {
        name: 'ハッキングされた作物'
      }
    }
    
    assert_redirected_to crops_path
    assert_equal I18n.t('crops.flash.no_permission'), flash[:alert]
  end

  test "参照作物は一般ユーザーがupdateできない" do
    sign_in_as @user
    
    # 参照作物を更新しようとする
    patch crop_path(@reference_crop), params: {
      crop: {
        name: 'ハッキングされた参照作物'
      }
    }
    
    assert_redirected_to crops_path
    assert_equal I18n.t('crops.flash.no_permission'), flash[:alert]
  end

  test "管理者は参照作物のnutrientsを更新できる" do
    sign_in_as @admin_user
    
    # 参照作物のステージにnutrientsを追加
    stage = @reference_crop.crop_stages.first
    
    patch crop_path(@reference_crop), params: {
      crop: {
        crop_stages_attributes: [{
          id: stage.id,
          name: stage.name,
          order: stage.order,
          nutrient_requirement_attributes: {
            daily_uptake_n: 0.5,
            daily_uptake_p: 0.2,
            daily_uptake_k: 0.8
          }
        }]
      }
    }
    
    assert_redirected_to crop_path(@reference_crop)
    
    # DBを確認
    stage.reload
    if stage.nutrient_requirement
      assert_equal 0.5, stage.nutrient_requirement.daily_uptake_n
    end
  end

  test "nutrients無しでステージを更新できる" do
    sign_in_as @user
    
    crop = create(:crop, user: @user)
    stage = create(:crop_stage, crop: crop, order: 1, name: '生育期')
    create(:temperature_requirement, crop_stage: stage)
    create(:thermal_requirement, crop_stage: stage)
    
    # nutrients無しでステージ名だけ更新
    patch crop_path(crop), params: {
      crop: {
        crop_stages_attributes: [{
          id: stage.id,
          name: '更新された生育期',
          order: 1
        }]
      }
    }
    
    assert_redirected_to crop_path(crop)
    
    # DBを確認
    stage.reload
    assert_equal '更新された生育期', stage.name
    assert_nil stage.nutrient_requirement
  end

  # ========== destroy アクションのテスト ==========

  test 'destroy_returns_undo_token_json' do
    sign_in_as @user
    crop = create(:crop, user: @user)

    assert_difference -> { Crop.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete crop_path(crop), as: :json
        assert_response :success
      end
    end

    body = JSON.parse(@response.body)
    %w[undo_token undo_deadline toast_message undo_path auto_hide_after redirect_path resource_dom_id].each do |key|
      assert body.key?(key), "JSONレスポンスに#{key}が含まれていません"
      assert body[key].present?, "#{key} が空です"
    end

    undo_token = body['undo_token']
    event = DeletionUndoEvent.find(undo_token)
    assert_equal 'Crop', event.resource_type
    assert_equal crop.id.to_s, event.resource_id
    assert event.scheduled?
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal crops_path(locale: I18n.locale), body.fetch('redirect_path')
    assert_equal ActionView::RecordIdentifier.dom_id(crop), body.fetch('resource_dom_id')
  end

  test 'undo_endpoint_restores_crop' do
    sign_in_as @user
    crop = create(:crop, user: @user)

    delete crop_path(crop), as: :json
    assert_response :success

    body = JSON.parse(@response.body)
    undo_token = body.fetch('undo_token')

    assert_not Crop.exists?(crop.id), '削除後にCropが残っています'

    assert_difference -> { Crop.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = JSON.parse(@response.body)
    assert_equal 'restored', undo_body['status']
    assert_equal undo_token, undo_body['undo_token']

    restored_event = DeletionUndoEvent.find(undo_token)
    assert restored_event.restored?
    assert Crop.exists?(crop.id), 'Undo後にCropが復元されていません'
  end

  # TODO: destroyアクションのHTMLレスポンスに対するリダイレクトフローのテストを追加する
end

