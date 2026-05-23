# frozen_string_literal: true

require "domain_lib_test_helper"

class FertilizeDetailInteractorTest < DomainLibTestCase
  test "call passes fertilize detail dto to output port" do
    user = stub(id: 42, admin?: false)
    entity = stub(
      id: 1,
      name: "Test",
      n: nil,
      p: nil,
      k: nil,
      description: nil,
      package_size: nil,
      is_reference: false,
      user_id: 42,
      created_at: nil,
      updated_at: nil
    )
    translator = mock

    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    gateway = mock
    gateway.expects(:find_by_id).with("99").returns(entity)

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
    user_lookup.expects(:find).with(42).returns(stub(id: 42, admin?: false))

    gateway = mock
    gateway.expects(:find_by_id).with("1").raises(StandardError.new("boom"))

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
    user_lookup.expects(:find).with(42).returns(stub(id: 42, admin?: false))

    gateway = mock
    gateway.expects(:find_by_id).with("1").raises(Domain::Shared::Exceptions::RecordNotFound.new("internal"))

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
    user = stub(id: 42, admin?: false)
    user_lookup = mock
    user_lookup.expects(:find).with(42).returns(user)

    entity = stub(is_reference: false, user_id: 99)
    gateway = mock
    gateway.expects(:find_by_id).with("1").returns(entity)

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
