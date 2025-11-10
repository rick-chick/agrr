require 'test_helper'

class DeletionUndoManagerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  def setup
    @user = create(:user)
    @crop = create(:crop, :reference)
    @pest = create(:pest)
    @pesticide = create(:pesticide, :complete, crop: @crop, pest: @pest, is_reference: true)
    @usage_constraint_id = @pesticide.pesticide_usage_constraint&.id
    @application_detail_id = @pesticide.pesticide_application_detail&.id
  end

  test 'schedule_creates_snapshot_and_removes_record' do
    event = nil
    assert_difference -> { DeletionUndoEvent.count }, +1 do
      assert_difference -> { Pesticide.count }, -1 do
        event = DeletionUndo::Manager.schedule(record: @pesticide, actor: @user)
      end
    end

    assert_kind_of DeletionUndoEvent, event
    assert_match(/\A[0-9a-fA-F-]{36}\z/, event.undo_token, 'schedule が UUID を返すことを期待')

    snapshot = event.reload.snapshot

    assert_equal @pesticide.class.name, snapshot.fetch('model')
    assert_equal @pesticide.id, snapshot.fetch('attributes').fetch('id')

    usage_snapshot = snapshot.dig('associations', 'pesticide_usage_constraint')
    application_snapshot = snapshot.dig('associations', 'pesticide_application_detail')

    assert_equal 'PesticideUsageConstraint', usage_snapshot.fetch('model')
    assert_equal @usage_constraint_id, usage_snapshot.fetch('attributes').fetch('id')

    assert_equal 'PesticideApplicationDetail', application_snapshot.fetch('model')
    assert_equal @application_detail_id, application_snapshot.fetch('attributes').fetch('id')
  end

  test 'restore_recreates_record_with_associations' do
    event = nil
    assert_difference -> { DeletionUndoEvent.count }, +1 do
      assert_difference -> { Pesticide.count }, -1 do
        event = DeletionUndo::Manager.schedule(record: @pesticide, actor: @user)
      end
    end

    undo_token = event.undo_token
    assert_nil Pesticide.find_by(id: @pesticide.id), 'スケジュール後はレコードが削除されているはず'

    assert_difference -> { Pesticide.count }, +1 do
      DeletionUndo::Manager.restore!(undo_token: undo_token)
    end

    restored = Pesticide.find(@pesticide.id)
    assert_not_nil restored, '復元後に同じ ID のレコードが存在すること'
    restored_usage = restored.pesticide_usage_constraint
    restored_application = restored.pesticide_application_detail

    assert_equal @usage_constraint_id, restored_usage&.id
    assert_equal @application_detail_id, restored_application&.id

    assert_equal 'restored', event.reload.state
  end

  test 'task_schedule_item snapshot retains schedule references' do
    plan = create(:cultivation_plan, :completed, user: @user)
    field_cultivation = create(:field_cultivation, cultivation_plan: plan)
    schedule = create(:task_schedule, cultivation_plan: plan, field_cultivation: field_cultivation, category: 'general')
    agricultural_task = create(:agricultural_task)
    item = create(:task_schedule_item,
                  task_schedule: schedule,
                  agricultural_task: agricultural_task,
                  scheduled_date: Date.current + 1.day,
                  name: '潅水')

    event = nil
    assert_difference -> { TaskScheduleItem.count }, -1 do
      event = DeletionUndo::Manager.schedule(
        record: item,
        actor: @user,
        toast_message: 'dummy'
      )
    end

    snapshot = event.snapshot
    attributes = snapshot.fetch('attributes')

    assert_equal item.id, attributes.fetch('id')
    assert_equal schedule.id, attributes.fetch('task_schedule_id')
    assert_equal agricultural_task.id, attributes.fetch('agricultural_task_id')
    assert_equal (Date.current + 1.day), Date.parse(attributes.fetch('scheduled_date')).to_date if attributes['scheduled_date'].present?

    assert_not TaskScheduleItem.exists?(item.id), '削除後にTaskScheduleItemが残っています'

    assert_difference -> { TaskScheduleItem.count }, +1 do
      DeletionUndo::Manager.restore!(undo_token: event.undo_token)
    end

    restored = TaskScheduleItem.find(item.id)
    assert_equal schedule.id, restored.task_schedule_id
    assert_equal agricultural_task.id, restored.agricultural_task_id
    assert_equal item.scheduled_date, restored.scheduled_date
    assert_equal item.name, restored.name
  end

  test 'restore_after_expiration_fails' do
    event = nil
    assert_difference -> { DeletionUndoEvent.count }, +1 do
      assert_difference -> { Pesticide.count }, -1 do
        event = DeletionUndo::Manager.schedule(record: @pesticide, actor: @user)
      end
    end

    undo_token = event.undo_token

    travel_to(event.expires_at + 1.minute) do
      assert_raises DeletionUndo::ExpiredTokenError do
        DeletionUndo::Manager.restore!(undo_token: undo_token)
      end
    end

    assert_nil Pesticide.find_by(id: @pesticide.id), '期限切れではレコードが復元されないはず'
    assert_equal 'expired', event.reload.state, '期限切れ後の状態更新を確認'
  end
end
