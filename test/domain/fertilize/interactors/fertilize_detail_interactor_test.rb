# frozen_string_literal: true

require "domain_lib_test_helper"

class FertilizeDetailInteractorTest < DomainLibTestCase
  test "call passes fertilize detail dto to output port" do
    user = mock
    entity = mock
    entity.stubs(:id).returns(1)
    entity.stubs(:name).returns("Test")
    entity.stubs(:n).returns(nil)
    entity.stubs(:p).returns(nil)
    entity.stubs(:k).returns(nil)
    entity.stubs(:description).returns(nil)
    entity.stubs(:package_size).returns(nil)
    entity.stubs(:is_reference).returns(false)
    entity.stubs(:created_at).returns(nil)
    entity.stubs(:updated_at).returns(nil)
    translator = mock

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    gateway = mock
    gateway.expects(:find_authorized_for_view).with(user, "99", access_filter: anything).returns(entity)

    output = mock
    output.expects(:on_success).with do |dto|
      assert_instance_of Domain::Fertilize::Dtos::FertilizeDetailOutput, dto
      assert_instance_of Domain::Fertilize::Dtos::FertilizeDisplay, dto.display_dto
      assert_equal 1, dto.display_dto.id
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

  test "propagates unexpected StandardError from gateway" do
    translator = mock
    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(mock)

    gateway = mock
    gateway.expects(:find_authorized_for_view).with(anything, anything, access_filter: anything).raises(StandardError.new("boom"))

    output = mock

    interactor = Domain::Fertilize::Interactors::FertilizeDetailInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      translator: translator,
      user_lookup: user_lookup
    )
    assert_raises(StandardError, "boom") do
      interactor.call("1")
    end
  end

  test "call maps RecordNotFound to translated not_found flash" do
    translator = mock
    translator.expects(:t).with("fertilizes.flash.not_found").returns("指定された肥料が見つかりません。")

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(mock)

    gateway = mock
    gateway.expects(:find_authorized_for_view).with(anything, anything, access_filter: anything).raises(Domain::Shared::Exceptions::RecordNotFound.new("internal"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_instance_of Domain::Shared::Dtos::Error, err
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

  test "call forwards PolicyPermissionDenied to on_failure" do
    translator = mock
    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(mock)

    gateway = mock
    gateway.expects(:find_authorized_for_view).with(anything, anything, access_filter: anything).raises(Domain::Shared::Policies::PolicyPermissionDenied)

    received = nil
    output = mock
    output.expects(:on_failure).with(instance_of(Domain::Shared::Policies::PolicyPermissionDenied)) { |e| received = e }

    interactor = Domain::Fertilize::Interactors::FertilizeDetailInteractor.new(
      output_port: output,
      user_id: 42,
      gateway: gateway,
      translator: translator,
      user_lookup: user_lookup
    )
    interactor.call("1")

    assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
  end
end
