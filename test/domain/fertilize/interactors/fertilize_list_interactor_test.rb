# frozen_string_literal: true

require "test_helper"

class FertilizeListInteractorTest < ActiveSupport::TestCase
  test "call passes fertilize entities to output port" do
    user = mock
    e1 = mock
    e2 = mock

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    gateway = mock
    gateway.expects(:list_index_for_user).with(user).returns([ e1, e2 ])

    output = mock
    output.expects(:on_success).with([ e1, e2 ])

    interactor = Domain::Fertilize::Interactors::FertilizeListInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      user_lookup: user_lookup
    )
    interactor.call
  end

  test "call forwards policy permission denied to on_failure as exception" do
    user = mock
    err = Domain::Shared::Policies::PolicyPermissionDenied.new

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    gateway = mock
    gateway.expects(:list_index_for_user).with(user).raises(err)

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
    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(mock)

    gateway = mock
    gateway.expects(:list_index_for_user).raises(StandardError.new("boom"))

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
