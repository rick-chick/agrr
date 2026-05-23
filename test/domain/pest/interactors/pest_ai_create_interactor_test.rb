# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class PestAiCreateInteractorTest < DomainLibTestCase
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
          def t(_key, default: nil)
            default || "name required"
          end
        end

        test "calls on_failure when pest name is blank" do
          user = Object.new
          def user.anonymous?
            false
          end

          spy = OutputPortSpy.new
          interactor = PestAiCreateInteractor.new(
            output_port: spy,
            user_id: 1,
            user_lookup: UserLookupFake.new(user),
            pest_gateway: Object.new,
            pest_ai_query_gateway: Object.new,
            create_interactor: Object.new,
            update_interactor: Object.new,
            logger: Object.new,
            translator: TranslatorFake.new,
            associate_affected_crops_runner: ->(_pest_id, _crops) {}
          )

          interactor.call(pest_name: "", affected_crops: [])

          assert_instance_of Domain::Pest::Dtos::PestAiCreateFailure, spy.failure
          assert_equal :bad_request, spy.failure.http_status
        end
      end
    end
  end
end
