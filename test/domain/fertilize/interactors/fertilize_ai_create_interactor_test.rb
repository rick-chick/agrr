# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Fertilize
    module Interactors
      class FertilizeAiCreateInteractorTest < DomainLibTestCase
        class OutputPortSpy
          attr_reader :failure

          def on_success(_dto); end

          def on_failure(dto)
            @failure = dto
          end
        end

        class UserLookupFake
          def initialize(user)
            @user = user
          end

          def find(_id)
            @user
          end
        end

        class TranslatorFake
          def t(_key)
            "login required"
          end
        end

        test "calls on_failure when user is anonymous" do
          user = Object.new
          def user.anonymous?
            true
          end

          spy = OutputPortSpy.new
          interactor = FertilizeAiCreateInteractor.new(
            output_port: spy,
            user_id: 1,
            user_lookup: UserLookupFake.new(user),
            fertilize_gateway: Object.new,
            fertilize_ai_query_gateway: Object.new,
            create_interactor: Object.new,
            update_interactor: Object.new,
            logger: Object.new,
            translator: TranslatorFake.new
          )

          interactor.call(fertilize_query_name: "尿素")

          assert_instance_of Domain::Fertilize::Dtos::FertilizeAiCreateFailure, spy.failure
          assert_equal :unauthorized, spy.failure.http_status
        end
      end
    end
  end
end
