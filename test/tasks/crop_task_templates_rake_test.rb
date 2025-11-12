require 'test_helper'
require 'rake'

class CropTaskTemplatesRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @task = Rake::Task['agrr:backfill_crop_task_templates']
    @task.reenable

    @user = create(:user)
    @crop_included = create(:crop, user: @user)
    @crop_excluded = create(:crop, user: @user)

    @task_included = create(:agricultural_task, :user_owned, user: @user)
    @task_excluded = create(:agricultural_task, :user_owned, user: @user)

    AgriculturalTaskCrop.create!(crop: @crop_included, agricultural_task: @task_included)
    AgriculturalTaskCrop.create!(crop: @crop_excluded, agricultural_task: @task_excluded)
  end

  test 'backfills templates for specified crop ids only' do
    ENV['CROP_IDS'] = @crop_included.id.to_s

    assert_difference -> { CropTaskTemplate.where(crop: @crop_included).count }, 1 do
      assert_no_difference -> { CropTaskTemplate.where(crop: @crop_excluded).count } do
        @task.invoke
      end
    end
  ensure
    ENV.delete('CROP_IDS')
  end
end


