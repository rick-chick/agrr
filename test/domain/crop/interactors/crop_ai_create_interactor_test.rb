# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropAiCreateInteractorTest < DomainLibTestCase
        class OutputPortSpy
          attr_reader :success, :failure

          def on_success(dto)
            @success = dto
          end

          def on_failure(dto)
            @failure = dto
          end
        end

        class UserLookupFake
          def initialize(user)
            @user = user
          end

          def find(_user_id)
            @user
          end
        end

        class TranslatorFake
          def initialize(messages = {})
            @messages = messages
          end

          def t(key)
            @messages.fetch(key) { key }
          end
        end

        test "calls on_failure when user is anonymous" do
          user = Object.new
          def user.anonymous?
            true
          end

          spy = OutputPortSpy.new
          interactor = CropAiCreateInteractor.new(
            output_port: spy,
            user_id: 1,
            user_lookup: UserLookupFake.new(user),
            translator: TranslatorFake.new("auth.api.login_required" => "login required"),
            logger: Object.new,
            crop_ai_query_gateway: Object.new,
            persistence: Object.new
          )

          interactor.call(crop_name: "トマト")

          assert_nil spy.success
          assert_instance_of Domain::Crop::Dtos::CropAiCreateFailure, spy.failure
          assert_equal :unauthorized, spy.failure.http_status
        end

        test "calls on_failure when crop name is blank" do
          user = Object.new
          def user.anonymous?
            false
          end

          spy = OutputPortSpy.new
          interactor = CropAiCreateInteractor.new(
            output_port: spy,
            user_id: 1,
            user_lookup: UserLookupFake.new(user),
            translator: TranslatorFake.new("api.errors.crops.name_required" => "name required"),
            logger: Object.new,
            crop_ai_query_gateway: Object.new,
            persistence: Object.new
          )

          interactor.call(crop_name: "  ")

          assert_nil spy.success
          assert_instance_of Domain::Crop::Dtos::CropAiCreateFailure, spy.failure
          assert_equal :bad_request, spy.failure.http_status
        end
      end
    end
  end
end
