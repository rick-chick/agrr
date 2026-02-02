# frozen_string_literal: true

require 'test_helper'

module Crops
  class TaskScheduleBlueprintDeletionServiceTest < ActiveSupport::TestCase
    test 'deletes blueprint and template when no remaining blueprints' do
      blueprint = mock('blueprint')
      crop = mock('crop')

      blueprint.expects(:destroy!).returns(true)
      blueprint.stubs(:agricultural_task_id).returns(42)

      # Simulate no remaining blueprints
      crop_stubs = mock('relation')
      crop_stubs.stubs(:where).returns(stub(exists?: false))
      crop.stubs(:crop_task_schedule_blueprints).returns(crop_stubs)

      template = mock('template')
      template.stubs(:id).returns(123)
      template.expects(:destroy!).returns(true)
      crop.stubs(:crop_task_templates).returns(stub(find_by: template))

      service = Crops::TaskScheduleBlueprintDeletionService.new(crop: crop, blueprint: blueprint)
      result = service.call

      assert_equal true, result[:blueprint_deleted]
      assert_equal true, result[:template_deleted]

      # mocha will verify expectations automatically
    end

    test 'does not delete template when other blueprints remain' do
      blueprint = mock('blueprint')
      crop = mock('crop')

      blueprint.expects(:destroy!).returns(true)
      blueprint.stubs(:agricultural_task_id).returns(99)

      crop_stubs = mock('relation')
      crop_stubs.stubs(:where).returns(stub(exists?: true))
      crop.stubs(:crop_task_schedule_blueprints).returns(crop_stubs)

      # Ensure find_by is not called (returns nil)
      crop.stubs(:crop_task_templates).returns(stub(find_by: nil))

      service = Crops::TaskScheduleBlueprintDeletionService.new(crop: crop, blueprint: blueprint)
      result = service.call

      assert_equal true, result[:blueprint_deleted]
      assert_equal false, result[:template_deleted]

      # mocha verifies
    end

    test 'handles blueprint without agricultural_task_id' do
      blueprint = mock('blueprint')
      crop = mock('crop')

      blueprint.expects(:destroy!).returns(true)
      blueprint.stubs(:agricultural_task_id).returns(nil)

      # crop relations should not be queried in this case, but stub to be safe
      crop.stubs(:crop_task_schedule_blueprints).returns(stub(where: stub(exists?: false)))
      crop.stubs(:crop_task_templates).returns(stub(find_by: nil))

      service = Crops::TaskScheduleBlueprintDeletionService.new(crop: crop, blueprint: blueprint)
      result = service.call

      assert_equal true, result[:blueprint_deleted]
      assert_equal false, result[:template_deleted]

      # mocha verifies
    end
  end
end

