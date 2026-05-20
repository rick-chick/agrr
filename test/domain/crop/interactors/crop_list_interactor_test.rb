# frozen_string_literal: true

require "domain_lib_test_helper"

class Domain::Crop::Interactors::CropListInteractorTest < DomainLibTestCase
  test "call loads crops using policy-built filter for regular user" do
    user = Object.new
    def user.id; 42; end
    def user.admin?; false; end

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    expected_filter = Domain::Shared::Policies::CropPolicy.index_list_filter(user)
    e1 = mock
    e2 = mock
    gateway = mock
    gateway.expects(:list_index_for_filter).with(expected_filter).returns([ e1, e2 ])

    output = mock
    output.expects(:on_success).with([ e1, e2 ])

    Domain::Crop::Interactors::CropListInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      user_lookup: user_lookup
    ).call
  end

  test "call loads crops using policy-built filter for admin" do
    user = Object.new
    def user.id; 99; end
    def user.admin?; true; end

    user_lookup = mock
    user_lookup.expects(:find).with(99).returns(user)

    expected_filter = Domain::Shared::Policies::CropPolicy.index_list_filter(user)
    gateway = mock
    gateway.expects(:list_index_for_filter).with(expected_filter).returns([])

    output = mock
    output.expects(:on_success).with([])

    Domain::Crop::Interactors::CropListInteractor.new(
      output_port: output,
      user_id: 99,
      gateway: gateway,
      user_lookup: user_lookup
    ).call
  end

  test "call maps RecordNotFound to failure Error" do
    user = Object.new
    def user.id; 1; end
    def user.admin?; false; end

    user_lookup = mock
    user_lookup.expects(:find).with(1).returns(user)

    expected_filter = Domain::Shared::Policies::CropPolicy.index_list_filter(user)
    gateway = mock
    gateway.expects(:list_index_for_filter).with(expected_filter).raises(Domain::Shared::Exceptions::RecordNotFound.new("x"))

    output = mock
    output.expects(:on_failure).with { |dto| dto.is_a?(Domain::Shared::Dtos::Error) && dto.message == "x" }

    Domain::Crop::Interactors::CropListInteractor.new(
      output_port: output,
      user_id: 1,
      gateway: gateway,
      user_lookup: user_lookup
    ).call
  end
end
