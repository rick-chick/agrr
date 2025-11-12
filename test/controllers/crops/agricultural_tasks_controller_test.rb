# frozen_string_literal: true

require 'test_helper'

module Crops
  class AgriculturalTasksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user)
      session_id = create_session_for(@user)
      @headers = session_cookie_header(session_id)

      @crop = create(:crop, user: @user)
      @task = create(:agricultural_task, :user_owned, user: @user, name: '整枝')
    end

    test 'ユーザーは既存作業からテンプレートを生成できる' do
      assert_difference('CropTaskTemplate.count', 1) do
        post crop_agricultural_tasks_path(@crop),
             params: { agricultural_task_id: @task.id },
             headers: @headers
      end

      assert_redirected_to crop_agricultural_tasks_path(@crop)

      template = @crop.crop_task_templates.find_by!(agricultural_task: @task)
      assert_equal @task.name, template.name
      assert AgriculturalTaskCrop.exists?(crop: @crop, agricultural_task: @task)

      assert_equal I18n.t('crops.agricultural_tasks.flash.template_created'),
                   flash[:notice]
    end

    test '既にテンプレートが存在する場合は再生成しない' do
      create(:crop_task_template, crop: @crop, agricultural_task: @task, name: @task.name)

      assert_no_difference('CropTaskTemplate.count') do
        post crop_agricultural_tasks_path(@crop),
             params: { agricultural_task_id: @task.id },
             headers: @headers
      end

      assert_redirected_to crop_agricultural_tasks_path(@crop)
      assert_equal I18n.t('crops.agricultural_tasks.flash.template_already_exists'),
                   flash[:alert]
    end

    test 'ユーザーはテンプレートを編集・削除できる' do
      template = create(:crop_task_template,
                        crop: @crop,
                        agricultural_task: @task,
                        name: '整枝テンプレート')

      patch crop_agricultural_task_path(@crop, template),
            params: {
              crop_task_template: {
                name: '整枝（更新）',
                description: '更新説明'
              }
            },
            headers: @headers

      assert_redirected_to crop_agricultural_tasks_path(@crop)
      template.reload
      assert_equal '整枝（更新）', template.name
      assert_equal '更新説明', template.description

      assert_difference('CropTaskTemplate.count', -1) do
        delete crop_agricultural_task_path(@crop, template),
               headers: @headers
      end

      assert_redirected_to crop_agricultural_tasks_path(@crop)
    end
  end
end


