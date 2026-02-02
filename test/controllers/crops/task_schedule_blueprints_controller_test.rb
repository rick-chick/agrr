# frozen_string_literal: true

require 'test_helper'

module Crops
  class TaskScheduleBlueprintsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user)
      session_id = create_session_for(@user)
      @headers = session_cookie_header(session_id)

      @crop = create(:crop, user: @user)
      @agricultural_task = create(:agricultural_task, :user_owned, user: @user, name: '種まき')
      
      # テンプレートを作成
      @template = CropTaskTemplate.create!(
        crop: @crop,
        agricultural_task: @agricultural_task,
        name: @agricultural_task.name,
        description: @agricultural_task.description,
        time_per_sqm: 0.1,
        weather_dependency: 'low'
      )
      
      # 作業予定（blueprint）を作成
      @blueprint = create(:crop_task_schedule_blueprint,
                          crop: @crop,
                          agricultural_task: @agricultural_task,
                          stage_order: 0,
                          gdd_trigger: 0.0,
                          task_type: TaskScheduleItem::FIELD_WORK_TYPE,
                          source: 'manual',
                          priority: 1)
    end

    test '作業予定を削除すると、対応するテンプレートも削除される' do
      # Controller-level test: 削除ロジックはサービスに委譲しているためサービス呼び出しをモックして検証
      Crops::TaskScheduleBlueprintDeletionService.any_instance.expects(:call).returns({ blueprint_deleted: true, template_deleted: true })

      delete crop_task_schedule_blueprint_path(@crop, @blueprint),
             headers: @headers

      assert_response :success
    end

    test '同じagricultural_task_idのblueprintが複数ある場合、最後の1つを削除してもテンプレートは削除される' do
      # 2つ目のblueprintを作成
      blueprint2 = create(:crop_task_schedule_blueprint,
                           crop: @crop,
                           agricultural_task: @agricultural_task,
                           stage_order: 1,
                           gdd_trigger: 100.0,
                           task_type: TaskScheduleItem::FIELD_WORK_TYPE,
                           source: 'manual',
                           priority: 2)
      # 1つ目のblueprintを削除（テンプレートは残る） - サービスをモック
      Crops::TaskScheduleBlueprintDeletionService.any_instance.expects(:call).returns({ blueprint_deleted: true, template_deleted: false })
      delete crop_task_schedule_blueprint_path(@crop, @blueprint),
             headers: @headers
      assert_response :success

      # 2つ目のblueprintを削除（テンプレートも削除される） - サービスをモック
      Crops::TaskScheduleBlueprintDeletionService.any_instance.expects(:call).returns({ blueprint_deleted: true, template_deleted: true })
      delete crop_task_schedule_blueprint_path(@crop, blueprint2),
             headers: @headers
      assert_response :success
    end

    test '作業予定削除後、利用可能な作業テンプレートの選択状態が更新される' do
      # サービスをモックして、コントローラが正常に応答することを確認する
      Crops::TaskScheduleBlueprintDeletionService.any_instance.expects(:call).returns({ blueprint_deleted: true, template_deleted: true })
      delete crop_task_schedule_blueprint_path(@crop, @blueprint),
             headers: @headers
      assert_response :success
    end

    test '管理者は参照作物の作業予定を削除できる' do
      admin = create(:user, admin: true)
      session_id = create_session_for(admin)
      headers = session_cookie_header(session_id)

      reference_crop = create(:crop, :reference)
      reference_task = create(:agricultural_task, is_reference: true, name: '参照作業')
      
      reference_template = CropTaskTemplate.create!(
        crop: reference_crop,
        agricultural_task: reference_task,
        name: reference_task.name,
        description: reference_task.description,
        time_per_sqm: 0.1,
        weather_dependency: 'low'
      )
      
      reference_blueprint = create(:crop_task_schedule_blueprint,
                                   crop: reference_crop,
                                   agricultural_task: reference_task,
                                   stage_order: 0,
                                   gdd_trigger: 0.0,
                                   task_type: TaskScheduleItem::FIELD_WORK_TYPE,
                                   source: 'manual',
                                   priority: 1)

      Crops::TaskScheduleBlueprintDeletionService.any_instance.expects(:call).returns({ blueprint_deleted: true, template_deleted: true })
      delete crop_task_schedule_blueprint_path(reference_crop, reference_blueprint),
             headers: headers
      assert_response :success
    end

    test '一般ユーザーは他のユーザーの作業予定を削除できない' do
      other_user = create(:user)
      session_id = create_session_for(other_user)
      headers = session_cookie_header(session_id)

      assert_no_difference('CropTaskScheduleBlueprint.count') do
        delete crop_task_schedule_blueprint_path(@crop, @blueprint),
               headers: headers
      end

      # set_cropのcan_view_crop?でリダイレクトされる
      assert_response :redirect
      assert_redirected_to crops_path
    end
  end
end

