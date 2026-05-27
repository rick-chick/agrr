# frozen_string_literal: true

module DomainLibTestSupport
  def domain_user_stub(id: 1, admin: false)
    stub(id: id, admin?: admin)
  end

  def domain_record_entity_stub(user_id:, is_reference: false, **extra)
    stub({ is_reference: is_reference, user_id: user_id }.merge(extra))
  end

  # ReferencableListRowMapper 経由の list interactor 用
  def expect_referencable_list_rows_on_success(output, records)
    output.expects(:on_success).with do |rows|
      assert_equal records.length, rows.length
      rows.zip(records).each do |row, record|
        assert_instance_of Domain::Shared::Dtos::ReferencableListRow, row
        assert_same record, row.record
      end
      true
    end
  end

  def schedulable_record_stub(type_name, is_reference: false, user_id: 1, **extra)
    klass = Class.new do
      define_singleton_method(:name) { type_name }
    end
    record = stub({ is_reference: is_reference, user_id: user_id }.merge(extra))
    record.stubs(:class).returns(klass)
    record
  end

  def public_field_cultivation_plan_context(field_cultivation_id)
    Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessContext.new(
      field_cultivation_id: field_cultivation_id,
      plan_type_public: true,
      plan_type_private: false,
      plan_user_id: nil
    )
  end

  def private_field_cultivation_plan_context(field_cultivation_id, plan_user_id: 1)
    Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessContext.new(
      field_cultivation_id: field_cultivation_id,
      plan_type_public: false,
      plan_type_private: true,
      plan_user_id: plan_user_id
    )
  end

  def attach_plan_access_context_to_gateway(gateway, field_cultivation_id, context: nil)
    ctx = context || public_field_cultivation_plan_context(field_cultivation_id)
    gateway.define_singleton_method(:find_plan_access_context) { |_id| ctx }
    gateway
  end

  def domain_private_plan_entity(id:, user_id:, farm_id: 1, total_area: 100.0)
    Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
      id: id,
      farm_id: farm_id,
      user_id: user_id,
      total_area: total_area,
      plan_type: "private"
    )
  end

  def build_deletion_undo_schedule_interactor(output_port:, gateway:, actor_id: 1, resource_type: "Crop", resource_id: 9)
    user = domain_user_stub(id: actor_id || 1, admin: true)
    user_lookup = Minitest::Mock.new
    user_lookup.expect(:find, user, [ actor_id ])

    record = schedulable_record_stub(resource_type, user_id: user.id)
    gateway.expect(:find_schedulable_record!, record, [ resource_type, resource_id ])

    interactor = Domain::DeletionUndo::Interactors::DeletionUndoScheduleInteractor.new(
      output_port: output_port,
      gateway: gateway,
      user_lookup: user_lookup
    )
    [ interactor, user_lookup ]
  end
end
