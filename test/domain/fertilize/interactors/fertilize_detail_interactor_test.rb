# frozen_string_literal: true

require "test_helper"

class FertilizeDetailInteractorTest < ActiveSupport::TestCase
  test "call passes fertilize detail dto to output port" do
    user = mock
    entity = mock
    translator = mock

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    gateway = mock
    gateway.expects(:find_authorized_for_view).with(user, "99").returns(entity)

    output = mock
    output.expects(:on_success).with do |dto|
      assert_instance_of Domain::Fertilize::Dtos::FertilizeDetailOutputDto, dto
      assert_same entity, dto.fertilize
      true
    end

    interactor = Domain::Fertilize::Interactors::FertilizeDetailInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      translator: translator,
      user_lookup: user_lookup
    )
    interactor.call("99")
  end

  test "call forwards errors to on_failure" do
    translator = mock
    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(mock)

    gateway = mock
    gateway.expects(:find_authorized_for_view).raises(StandardError.new("boom"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_instance_of Domain::Shared::Dtos::ErrorDto, err
      assert_equal "boom", err.message
      true
    end

    interactor = Domain::Fertilize::Interactors::FertilizeDetailInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      translator: translator,
      user_lookup: user_lookup
    )
    interactor.call("1")
  end

  test "call maps RecordNotFound to translated not_found flash" do
    translator = mock
    translator.expects(:t).with("fertilizes.flash.not_found").returns("指定された肥料が見つかりません。")

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(mock)

    gateway = mock
    gateway.expects(:find_authorized_for_view).raises(Domain::Shared::Exceptions::RecordNotFound.new("internal"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_instance_of Domain::Shared::Dtos::ErrorDto, err
      assert_equal "指定された肥料が見つかりません。", err.message
      true
    end

    interactor = Domain::Fertilize::Interactors::FertilizeDetailInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      translator: translator,
      user_lookup: user_lookup
    )
    interactor.call("1")
  end

  test "call re-raises PolicyPermissionDenied" do
    translator = mock
    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(mock)

    gateway = mock
    gateway.expects(:find_authorized_for_view).raises(Domain::Shared::Policies::PolicyPermissionDenied)

    output = mock
    output.expects(:on_success).never
    output.expects(:on_failure).never

    interactor = Domain::Fertilize::Interactors::FertilizeDetailInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      translator: translator,
      user_lookup: user_lookup
    )
    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      interactor.call("1")
    end
  end
end
