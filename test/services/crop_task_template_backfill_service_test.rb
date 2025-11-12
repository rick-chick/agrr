require "test_helper"

class CropTaskTemplateBackfillServiceTest < ActiveSupport::TestCase
  setup do
    @crop = create(:crop)
    @task = create(:agricultural_task, :user_owned, user: @crop.user)
    AgriculturalTaskCrop.create!(crop: @crop, agricultural_task: @task)
  end

  test "農業タスクの関連付けから作業テンプレートを生成する" do
    service = CropTaskTemplateBackfillService.new

    service.call

    template = CropTaskTemplate.find_by(crop: @crop, source_agricultural_task_id: @task.id)
    assert_not_nil template
    assert_equal @task.name, template.name
    assert_equal @task.description, template.description
    assert_in_delta @task.time_per_sqm, template.time_per_sqm
    assert_equal @task.weather_dependency, template.weather_dependency
    assert_equal @task.required_tools, template.required_tools
    assert_equal @task.skill_level, template.skill_level
    assert_equal @task, template.agricultural_task
  end

  test "二重実行してもテンプレートが重複しない" do
    service = CropTaskTemplateBackfillService.new
    service.call

    assert_no_difference -> { CropTaskTemplate.count } do
      service.call
    end
  end

  test "指定した作物のみテンプレート化する" do
    other_crop = create(:crop)
    other_task = create(:agricultural_task, :user_owned, user: other_crop.user)
    AgriculturalTaskCrop.create!(crop: other_crop, agricultural_task: other_task)

    service = CropTaskTemplateBackfillService.new
    service.call(crop_ids: [@crop.id])

    assert CropTaskTemplate.exists?(crop: @crop, agricultural_task: @task)
    refute CropTaskTemplate.exists?(crop: other_crop, agricultural_task: other_task)
  end
end
