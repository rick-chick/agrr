# frozen_string_literal: true

module DomainLibTestSupport
  def domain_user_stub(id: 1, admin: false)
    stub(id: id, admin?: admin)
  end

  def domain_record_entity_stub(user_id:, is_reference: false, **extra)
    stub({ is_reference: is_reference, user_id: user_id }.merge(extra))
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

  def stub_plan_access_find_private_owned!(user, plan_id, plan: nil, error: nil)
    expectation = Domain::CultivationPlan::Policies::PlanAccess.expects(:find_private_owned!).with(user, plan_id)
    if error
      expectation.raises(error)
    else
      expectation.returns(plan || stub(plan_type_private?: true, user_id: user.id))
    end
  end

  def stub_field_access_find_owned!(user, field_id, field: nil, error: nil)
    expectation = Domain::Field::Policies::FieldAccess.expects(:find_owned!).with(user, field_id)
    if error
      expectation.raises(error)
    else
      expectation.returns(field || stub)
    end
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
