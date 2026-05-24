# frozen_string_literal: true

require "domain_lib_test_helper"

class FertilizeListInteractorTest < DomainLibTestCase
  test "call passes fertilize entities to output port" do
    user = Object.new
    def user.id; 42; end
    def user.admin?; false; end
    e1 = domain_record_entity_stub(user_id: 42)
    e2 = domain_record_entity_stub(user_id: 42)

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    expected_filter = Domain::Shared::Policies::FertilizePolicy.index_list_filter(user)
    gateway = mock
    gateway.expects(:list_index_for_filter).with(expected_filter).returns([ e1, e2 ])

    output = mock
    expect_referencable_list_rows_on_success(output, [ e1, e2 ])

    interactor = Domain::Fertilize::Interactors::FertilizeListInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      user_lookup: user_lookup
    )
    interactor.call
  end

  test "call forwards policy permission denied to on_failure as exception" do
    user = Object.new
    def user.id; 42; end
    def user.admin?; false; end
    err = Domain::Shared::Policies::PolicyPermissionDenied.new

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    expected_filter = Domain::Shared::Policies::FertilizePolicy.index_list_filter(user)
    gateway = mock
    gateway.expects(:list_index_for_filter).with(expected_filter).raises(err)

    output = mock
    output.expects(:on_failure).with(err)

    interactor = Domain::Fertilize::Interactors::FertilizeListInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      user_lookup: user_lookup
    )
    interactor.call
  end

  test "propagates unexpected StandardError from gateway" do
    user = Object.new
    def user.id; 42; end
    def user.admin?; false; end
    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    expected_filter = Domain::Shared::Policies::FertilizePolicy.index_list_filter(user)
    gateway = mock
    gateway.expects(:list_index_for_filter).with(expected_filter).raises(StandardError.new("boom"))

    output = mock

    interactor = Domain::Fertilize::Interactors::FertilizeListInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      user_lookup: user_lookup
    )
    assert_raises(StandardError, "boom") do
      interactor.call
    end
  end
end
