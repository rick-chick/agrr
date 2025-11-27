# frozen_string_literal: true

require 'test_helper'

class AgriculturalTasksControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
    @admin_user = create(:user, admin: true)

    @reference_task = create(:agricultural_task)
    @user_task = create(:agricultural_task, :user_owned, user: @user)
    @admin_task = create(:agricultural_task, :user_owned, user: @admin_user)
  end

  test "includes HtmlCrudResponder" do
    assert_includes AgriculturalTasksController.included_modules, HtmlCrudResponder
  end

  test '一般ユーザーは自分の作業のみ一覧表示できる' do
    sign_in_as @user

    get agricultural_tasks_path

    assert_response :success
    assert_select '.agricultural-task-name', text: @user_task.name
    assert_select '.agricultural-task-name', text: @reference_task.name, count: 0
    assert_select '.agricultural-task-name', text: @admin_task.name, count: 0
  end

  test '管理者は参照作業と自分の作業を一覧表示できる' do
    sign_in_as @admin_user

    get agricultural_tasks_path

    assert_response :success
    assert_select '.agricultural-task-name', text: @reference_task.name
    assert_select '.agricultural-task-name', text: @admin_task.name
  end

  test '一般ユーザーは新規作業フォームに必要項目を表示できる' do
    sign_in_as @user

    get new_agricultural_task_path

    assert_response :success
    assert_select 'form[action="' + agricultural_tasks_path + '"][method="post"]' do
      assert_select 'input[name="agricultural_task[name]"]'
      assert_select 'textarea[name="agricultural_task[description]"]'
      assert_select 'input[name="agricultural_task[time_per_sqm]"]'
      assert_select 'select[name="agricultural_task[weather_dependency]"]'
      assert_select 'textarea[name="agricultural_task[required_tools]"]'
      assert_select 'select[name="agricultural_task[skill_level]"]'
      assert_select 'input[name="agricultural_task[is_reference]"]', false
    end
  end

  test '管理者の新規作業フォームには参照フラグが表示される' do
    sign_in_as @admin_user

    get new_agricultural_task_path

    assert_response :success
    assert_select 'form[action="' + agricultural_tasks_path + '"][method="post"]' do
      assert_select 'input[name="agricultural_task[is_reference]"][type="checkbox"]'
    end
  end

  test '一般ユーザーは自身の作業詳細を表示できる' do
    sign_in_as @user

    crop = create(:crop, user: @user, variety: '桃太郎')
    CropTaskTemplate.create!(
      crop: crop,
      agricultural_task: @user_task,
      name: @user_task.name,
      description: @user_task.description,
      time_per_sqm: @user_task.time_per_sqm,
      weather_dependency: @user_task.weather_dependency,
      required_tools: @user_task.required_tools,
      skill_level: @user_task.skill_level
    )

    get agricultural_task_path(@user_task)

    assert_response :success
    assert_select 'h1', text: @user_task.name
    assert_select '.associated-crops-grid .associated-crop-card', count: 1
    assert_select '.associated-crop-card__name', text: crop.name
    assert_select '.associated-crop-card__variety', text: "(#{crop.variety})"
  end

  test '編集フォームでユーザー自身の作物カードが表示され選択状態を切り替えられる' do
    sign_in_as @user

    selected_crop = create(:crop, user: @user, name: 'きゅうり')
    other_crop = create(:crop, user: @user, name: 'トマト')
    CropTaskTemplate.create!(
      crop: selected_crop,
      agricultural_task: @user_task,
      name: @user_task.name,
      description: @user_task.description,
      time_per_sqm: @user_task.time_per_sqm,
      weather_dependency: @user_task.weather_dependency,
      required_tools: @user_task.required_tools,
      skill_level: @user_task.skill_level
    )

    get edit_agricultural_task_path(@user_task)

    assert_response :success
    assert_select '[data-controller="crop-selector"]' do
      assert_select '[data-role="crop-card"]', count: 2
      assert_select %(article[data-role="crop-card"][data-crop-id="#{selected_crop.id}"][data-selected="true"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{other_crop.id}"][data-selected="false"]), 1
    end

    assert_select 'div[data-crop-selector-target="inputContainer"] input[name="selected_crop_ids[]"][value=?]', selected_crop.id.to_s
  end

  test 'ユーザー作業の編集フォームにはユーザー作物のみ表示される' do
    sign_in_as @admin_user

    reference_crop = create(:crop, :reference, name: '参照キャベツ')
    admin_crop = create(:crop, user: @admin_user, name: '管理用トマト')
    other_user_crop = create(:crop, user: @user, name: '他ユーザー作物')

    CropTaskTemplate.create!(
      crop: admin_crop,
      agricultural_task: @admin_task,
      name: @admin_task.name,
      description: @admin_task.description,
      time_per_sqm: @admin_task.time_per_sqm,
      weather_dependency: @admin_task.weather_dependency,
      required_tools: @admin_task.required_tools,
      skill_level: @admin_task.skill_level
    )

    get edit_agricultural_task_path(@admin_task)

    assert_response :success
    assert_select '[data-controller="crop-selector"]' do
      assert_select %(article[data-role="crop-card"][data-crop-id="#{admin_crop.id}"][data-selected="true"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{reference_crop.id}"]), 0
      assert_select %(article[data-role="crop-card"][data-crop-id="#{other_user_crop.id}"]), 0
    end
  end

  test '参照作業の編集フォームには参照作物のみ表示される' do
    sign_in_as @admin_user

    reference_crop = create(:crop, :reference, name: '参照ほうれん草')
    user_crop = create(:crop, user: @admin_user, name: '管理用ほうれん草')

    CropTaskTemplate.create!(
      crop: reference_crop,
      agricultural_task: @reference_task,
      name: @reference_task.name,
      description: @reference_task.description,
      time_per_sqm: @reference_task.time_per_sqm,
      weather_dependency: @reference_task.weather_dependency,
      required_tools: @reference_task.required_tools,
      skill_level: @reference_task.skill_level
    )

    get edit_agricultural_task_path(@reference_task)

    assert_response :success
    assert_select '[data-controller="crop-selector"]' do
      assert_select %(article[data-role="crop-card"][data-crop-id="#{reference_crop.id}"][data-selected="true"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{user_crop.id}"]), 0
    end
  end

  test '地域が設定されている場合は一致する地域の作物のみ表示される' do
    sign_in_as @user

    @user_task.update!(region: 'jp')
    matched_crop = create(:crop, user: @user, name: '地域内トマト', region: 'jp')
    unmatched_crop = create(:crop, user: @user, name: '地域外トマト', region: 'us')

    CropTaskTemplate.create!(
      crop: matched_crop,
      agricultural_task: @user_task,
      name: @user_task.name,
      description: @user_task.description,
      time_per_sqm: @user_task.time_per_sqm,
      weather_dependency: @user_task.weather_dependency,
      required_tools: @user_task.required_tools,
      skill_level: @user_task.skill_level
    )

    get edit_agricultural_task_path(@user_task)

    assert_response :success
    assert_select '[data-controller="crop-selector"]' do
      assert_select %(article[data-role="crop-card"][data-crop-id="#{matched_crop.id}"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{unmatched_crop.id}"]), 0
    end
  end

  test 'updateで選択した作物の関連付けが保存される' do
    sign_in_as @user

    keep_crop = create(:crop, user: @user, name: '残す')
    new_crop = create(:crop, user: @user, name: '追加する')
    removed_crop = create(:crop, user: @user, name: '外す')

    CropTaskTemplate.create!(
      crop: keep_crop,
      agricultural_task: @user_task,
      name: @user_task.name,
      description: @user_task.description,
      time_per_sqm: @user_task.time_per_sqm,
      weather_dependency: @user_task.weather_dependency,
      required_tools: @user_task.required_tools,
      skill_level: @user_task.skill_level
    )
    CropTaskTemplate.create!(
      crop: removed_crop,
      agricultural_task: @user_task,
      name: @user_task.name,
      description: @user_task.description,
      time_per_sqm: @user_task.time_per_sqm,
      weather_dependency: @user_task.weather_dependency,
      required_tools: @user_task.required_tools,
      skill_level: @user_task.skill_level
    )

    patch agricultural_task_path(@user_task), params: {
      agricultural_task: {
        name: @user_task.name,
        description: @user_task.description,
        time_per_sqm: @user_task.time_per_sqm,
        weather_dependency: @user_task.weather_dependency,
        skill_level: @user_task.skill_level,
        required_tools: @user_task.required_tools
      },
      selected_crop_ids: [keep_crop.id, new_crop.id]
    }

    assert_redirected_to agricultural_task_path(@user_task)
    @user_task.reload
    assert_equal [keep_crop.id, new_crop.id].sort, @user_task.crops.pluck(:id).sort
  end

  test '利用不可な作物IDは更新時に無視される' do
    sign_in_as @user

    own_crop = create(:crop, user: @user)
    other_user_crop = create(:crop, user: create(:user))

    patch agricultural_task_path(@user_task), params: {
      agricultural_task: {
        name: @user_task.name,
        description: @user_task.description,
        time_per_sqm: @user_task.time_per_sqm,
        weather_dependency: @user_task.weather_dependency,
        skill_level: @user_task.skill_level,
        required_tools: @user_task.required_tools
      },
      selected_crop_ids: [own_crop.id, other_user_crop.id]
    }

    assert_redirected_to agricultural_task_path(@user_task)
    @user_task.reload
    assert_equal [own_crop.id], @user_task.crops.pluck(:id)
  end

  test '一般ユーザーは参照作業を作成できない' do
    sign_in_as @user

    assert_no_difference('AgriculturalTask.count') do
      post agricultural_tasks_path, params: {
        agricultural_task: {
          name: '参照作業',
          is_reference: true
        }
      }
    end

    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t('agricultural_tasks.flash.reference_only_admin'), flash[:alert]
  end

  test '管理者が参照フラグを有効に変更するとユーザー作物の関連付けが解除される' do
    sign_in_as @admin_user

    user_crop = create(:crop, user: @admin_user, name: '管理用きゅうり')
    CropTaskTemplate.create!(
      crop: user_crop,
      agricultural_task: @admin_task,
      name: @admin_task.name,
      description: @admin_task.description,
      time_per_sqm: @admin_task.time_per_sqm,
      weather_dependency: @admin_task.weather_dependency,
      required_tools: @admin_task.required_tools,
      skill_level: @admin_task.skill_level
    )

    patch agricultural_task_path(@admin_task), params: {
      agricultural_task: {
        name: @admin_task.name,
        description: @admin_task.description,
        time_per_sqm: @admin_task.time_per_sqm,
        weather_dependency: @admin_task.weather_dependency,
        skill_level: @admin_task.skill_level,
        required_tools: @admin_task.required_tools,
        is_reference: true
      },
      selected_crop_ids: [user_crop.id]
    }

    assert_redirected_to agricultural_task_path(@admin_task)
    @admin_task.reload

    assert @admin_task.is_reference?
    assert_nil @admin_task.user_id
    assert_empty @admin_task.crops
  end

  test '参照フラグ変更後は許可された作物のみ関連付けられる' do
    sign_in_as @admin_user

    reference_crop = create(:crop, :reference, name: '参照キャベツ')
    user_crop = create(:crop, user: @admin_user, name: '管理トマト')
    CropTaskTemplate.create!(
      crop: reference_crop,
      agricultural_task: @reference_task,
      name: @reference_task.name,
      description: @reference_task.description,
      time_per_sqm: @reference_task.time_per_sqm,
      weather_dependency: @reference_task.weather_dependency,
      required_tools: @reference_task.required_tools,
      skill_level: @reference_task.skill_level
    )

    patch agricultural_task_path(@reference_task), params: {
      agricultural_task: {
        name: @reference_task.name,
        description: @reference_task.description,
        time_per_sqm: @reference_task.time_per_sqm,
        weather_dependency: @reference_task.weather_dependency,
        skill_level: @reference_task.skill_level,
        required_tools: @reference_task.required_tools,
        is_reference: false
      },
      selected_crop_ids: [reference_crop.id, user_crop.id]
    }

    assert_redirected_to agricultural_task_path(@reference_task)
    @reference_task.reload

    refute @reference_task.is_reference?
    assert_equal @admin_user.id, @reference_task.user_id
    assert_equal [user_crop.id], @reference_task.crops.pluck(:id)
  end

  test '一般ユーザーは参照フラグを変更できない' do
    sign_in_as @user
    task = create(:agricultural_task, :user_owned, user: @user, is_reference: false)

    patch agricultural_task_path(task), params: {
      agricultural_task: {
        name: task.name,
        description: task.description,
        time_per_sqm: task.time_per_sqm,
        weather_dependency: task.weather_dependency,
        skill_level: task.skill_level,
        required_tools: task.required_tools,
        is_reference: true
      }
    }

    assert_redirected_to agricultural_task_path(task)
    assert_equal I18n.t('agricultural_tasks.flash.reference_flag_admin_only'), flash[:alert]
    task.reload
    refute task.is_reference?
    assert_equal @user.id, task.user_id
  end

  test 'destroy_returns_undo_token_json' do
    sign_in_as @user
    task = create(:agricultural_task, :user_owned, user: @user)

    assert_difference -> { AgriculturalTask.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete agricultural_task_path(task), as: :json
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
    assert_equal 'AgriculturalTask', event.resource_type
    assert_equal task.id.to_s, event.resource_id
    assert event.scheduled?
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal agricultural_tasks_path(locale: I18n.locale), body.fetch('redirect_path')
    assert_equal dom_id(task), body.fetch('resource_dom_id')
    assert_equal task.name, body.fetch('resource')
  end

  test 'undo_endpoint_restores_agricultural_task' do
    sign_in_as @user
    task = create(:agricultural_task, :user_owned, user: @user)

    delete agricultural_task_path(task), as: :json
    assert_response :success

    body = JSON.parse(@response.body)
    undo_token = body.fetch('undo_token')

    assert_not AgriculturalTask.exists?(task.id), '削除後にAgriculturalTaskが残っています'

    assert_difference -> { AgriculturalTask.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = JSON.parse(@response.body)
    assert_equal 'restored', undo_body.fetch('status')
    assert_equal undo_token, undo_body.fetch('undo_token')

    restored_event = DeletionUndoEvent.find(undo_token)
    assert restored_event.restored?
    assert AgriculturalTask.exists?(task.id), 'Undo後にAgriculturalTaskが復元されていません'
  end

  test 'destroy_via_html_redirects_with_undo_notice' do
    sign_in_as @user
    task = create(:agricultural_task, :user_owned, user: @user, name: 'テスト作業')
    task_name = task.name

    assert_difference -> { AgriculturalTask.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete agricultural_task_path(task) # HTMLリクエスト
        assert_redirected_to agricultural_tasks_path
      end
    end

    expected_notice = I18n.t(
      'deletion_undo.redirect_notice',
      resource: task_name
    )
    assert_equal expected_notice, flash[:notice]
  end

  # ========== region編集のテスト ==========

  test "管理者は参照作業のregionを更新できる" do
    sign_in_as @admin_user
    
    patch agricultural_task_path(@reference_task), params: {
      agricultural_task: {
        name: @reference_task.name,
        region: 'us'
      }
    }
    
    assert_redirected_to agricultural_task_path(@reference_task)
    @reference_task.reload
    assert_equal 'us', @reference_task.region
  end

  test "管理者は自身の作業のregionを更新できる" do
    sign_in_as @admin_user
    task = create(:agricultural_task, :user_owned, user: @admin_user, region: 'jp')
    
    patch agricultural_task_path(task), params: {
      agricultural_task: {
        name: task.name,
        region: 'in'
      }
    }
    
    assert_redirected_to agricultural_task_path(task)
    task.reload
    assert_equal 'in', task.region
  end

  test "一般ユーザーはregionを更新できない" do
    sign_in_as @user
    task = create(:agricultural_task, :user_owned, user: @user, region: 'jp')
    
    patch agricultural_task_path(task), params: {
      agricultural_task: {
        name: task.name,
        region: 'us'
      }
    }
    
    assert_redirected_to agricultural_task_path(task)
    task.reload
    # regionは変更されない（パラメータに含まれても無視される）
    assert_equal 'jp', task.region
  end

  test "管理者は新規作業作成時にregionを設定できる" do
    sign_in_as @admin_user
    
    post agricultural_tasks_path, params: {
      agricultural_task: {
        name: '新規作業',
        is_reference: true,
        region: 'us'
      }
    }
    
    assert_redirected_to agricultural_task_path(AgriculturalTask.last)
    task = AgriculturalTask.last
    assert_equal 'us', task.region
  end

  test "一般ユーザーは新規作業作成時にregionを設定できない" do
    sign_in_as @user
    
    post agricultural_tasks_path, params: {
      agricultural_task: {
        name: '新規作業',
        region: 'us'
      }
    }
    
    assert_redirected_to agricultural_task_path(AgriculturalTask.last)
    task = AgriculturalTask.last
    # regionは設定されない（パラメータに含まれても無視される）
    assert_nil task.region
  end

  test '作成時に必須項目が欠けていると422でnewを再表示する' do
    sign_in_as @user

    assert_no_difference('AgriculturalTask.count') do
      post agricultural_tasks_path, params: {
        agricultural_task: {
          name: '' # 必須項目を空にする
        }
      }
    end

    assert_response :unprocessable_entity
  end
end


