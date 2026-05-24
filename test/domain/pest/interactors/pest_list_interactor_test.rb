# frozen_string_literal: true

require "domain_lib_test_helper"

class Domain::Pest::Interactors::PestListInteractorTest < DomainLibTestCase
  test "call loads pests using policy-built filter for regular user" do
    user = Object.new
    def user.id; 42; end
    def user.admin?; false; end

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    expected_filter = Domain::Shared::Policies::PestPolicy.index_list_filter(user)
    e1 = domain_record_entity_stub(user_id: 42)
    e2 = domain_record_entity_stub(user_id: 42)
    gateway = mock
    gateway.expects(:list_index_for_filter).with(expected_filter).returns([ e1, e2 ])

    output = mock
    expect_referencable_list_rows_on_success(output, [ e1, e2 ])

    Domain::Pest::Interactors::PestListInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      translator: mock,
      user_lookup: user_lookup
    ).call
  end

  test "call loads pests using policy-built filter for admin" do
    user = Object.new
    def user.id; 99; end
    def user.admin?; true; end

    user_lookup = mock
    user_lookup.expects(:find).with(99).returns(user)

    expected_filter = Domain::Shared::Policies::PestPolicy.index_list_filter(user)
    gateway = mock
    gateway.expects(:list_index_for_filter).with(expected_filter).returns([])

    output = mock
    output.expects(:on_success).with([])

    Domain::Pest::Interactors::PestListInteractor.new(
      output_port: output,
      user_id: 99,
      gateway: gateway,
      translator: mock,
      user_lookup: user_lookup
    ).call
  end

  test "call maps RecordInvalid to failure Error" do
    user = Object.new
    def user.id; 1; end
    def user.admin?; false; end

    user_lookup = mock
    user_lookup.expects(:find).with(1).returns(user)

    gateway = mock
    gateway.expects(:list_index_for_filter).raises(Domain::Shared::Exceptions::RecordInvalid.new("x"))

    output = mock
    output.expects(:on_failure).with { |dto| dto.is_a?(Domain::Shared::Dtos::Error) && dto.message == "x" }

    Domain::Pest::Interactors::PestListInteractor.new(
      output_port: output,
      user_id: 1,
      gateway: gateway,
      translator: mock,
      user_lookup: user_lookup
    ).call
  end
end
