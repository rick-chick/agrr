# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class PestAiUpdateInteractorTest < DomainLibTestCase
        UpdateResult = Struct.new(:success?, :data, :error, keyword_init: true)

        class TranslatorFake
          def t(key, default: nil, **)
            default || key
          end
        end

        def build_pest_entity(id: 7)
          Entities::PestEntity.new(
            id: id,
            user_id: 1,
            name: "アブラムシ",
            name_scientific: "Aphididae",
            family: "Aphididae",
            order: "Hemiptera",
            description: "desc",
            occurrence_season: "summer",
            region: nil,
            is_reference: false,
            created_at: nil,
            updated_at: nil
          )
        end

        def build_user
          user = Object.new
          def user.id
            1
          end

          def user.admin?
            true
          end

          user
        end

        setup do
          @user = build_user
          @user_lookup = mock("user_lookup")
          @user_lookup.stubs(:find).with(1).returns(@user)
          @pest_gateway = mock("pest_gateway")
          @pest_ai_gateway = mock("pest_ai_query_gateway")
          @update_interactor = mock("update_interactor")
          @logger = mock("logger")
          @logger.stubs(:info)
          @logger.stubs(:error)
          @interactor = PestAiUpdateInteractor.new(
            user_id: 1,
            user_lookup: @user_lookup,
            pest_gateway: @pest_gateway,
            pest_ai_query_gateway: @pest_ai_gateway,
            update_interactor: @update_interactor,
            logger: @logger,
            translator: TranslatorFake.new
          )
        end

        test "returns bad_request when pest query name is blank" do
          @pest_gateway.expects(:find_by_id).never
          @pest_ai_gateway.expects(:fetch_pest_json).never

          envelope = @interactor.call(pest_id: 7, pest_query_name: "  ")

          assert_equal :bad_request, envelope.status
          assert_equal "害虫名を入力してください", envelope.body[:error]
        end

        test "returns not_found when pest is not accessible" do
          @pest_gateway.expects(:find_by_id).with(7).raises(Domain::Shared::Exceptions::RecordNotFound)
          @pest_ai_gateway.expects(:fetch_pest_json).never

          envelope = @interactor.call(pest_id: 7, pest_query_name: "アブラムシ")

          assert_equal :not_found, envelope.status
          assert_equal "害虫が見つかりません", envelope.body[:error]
        end

        test "returns unprocessable_entity when update interactor fails" do
          pest = build_pest_entity
          @pest_gateway.expects(:find_by_id).with(7).returns(pest)
          @pest_ai_gateway.expects(:fetch_pest_json).with("アブラムシ", []).returns(
            "success" => true,
            "data" => { "pest" => { "name" => "アブラムシ" } }
          )
          @update_interactor.expects(:call).returns(
            UpdateResult.new(success?: false, data: nil, error: "validation failed")
          )
          @logger.expects(:error).with(includes("validation failed"))

          envelope = @interactor.call(pest_id: 7, pest_query_name: "アブラムシ")

          assert_equal :unprocessable_entity, envelope.status
          assert_equal "validation failed", envelope.body[:error]
        end

        test "returns ok envelope when agrr data updates pest successfully" do
          pest = build_pest_entity
          updated = build_pest_entity(id: 7)
          updated.define_singleton_method(:name) { "アブラムシ（更新）" }

          @pest_gateway.expects(:find_by_id).with(7).returns(pest)
          @pest_ai_gateway.expects(:fetch_pest_json).with("アブラムシ", []).returns(
            "success" => true,
            "data" => {
              "pest" => {
                "name" => "アブラムシ（更新）",
                "name_scientific" => "Aphididae",
                "family" => "Aphididae",
                "order" => "Hemiptera",
                "description" => "desc",
                "occurrence_season" => "summer"
              }
            }
          )
          @update_interactor.expects(:call).with(7, instance_of(Hash)).returns(
            UpdateResult.new(success?: true, data: updated, error: nil)
          )

          envelope = @interactor.call(pest_id: 7, pest_query_name: "アブラムシ")

          assert_equal :ok, envelope.status
          assert_equal true, envelope.body[:success]
          assert_equal 7, envelope.body[:pest_id]
          assert_equal "アブラムシ（更新）", envelope.body[:pest_name]
        end
      end
    end
  end
end
