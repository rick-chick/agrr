# frozen_string_literal: true

require "test_helper"

class FertilizeDestroyInteractorTest < ActiveSupport::TestCase
  test "calls on_failure with policy exception when permission denied" do
    user_id = 10
    user = Object.new
    fertilize_id = 7

    user_lookup = Minitest::Mock.new
    user_lookup.expect(:find, user, [ user_id ])

    gateway = Object.new
    gateway.define_singleton_method(:soft_destroy_with_undo) do |*_args, **_kw|
      raise Domain::Shared::Policies::PolicyPermissionDenied
    end

    received = nil
    output_port = Minitest::Mock.new
    output_port.expect(:on_failure, nil) { |arg| received = arg }

    interactor = Domain::Fertilize::Interactors::FertilizeDestroyInteractor.new(
      output_port: output_port,
      gateway: gateway,
      user_id: user_id,
      translator: Object.new,
      user_lookup: user_lookup
    )

    interactor.call(fertilize_id)

    assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
    user_lookup.verify
    output_port.verify
  end
end
