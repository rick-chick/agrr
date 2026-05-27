# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PlanSaveEnsureUserFertilizesInteractorTest < DomainLibTestCase
        def build_translator
          Object.new.tap do |o|
            o.define_singleton_method(:t) do |key, **opts|
              opts.empty? ? key.to_s : "#{key}|#{opts.sort.to_h.inspect}"
            end
          end
        end

        def fertilize_row(fertilize_id: 200, name: "肥料A")
          Dtos::PublicPlanSaveFertilizeReferenceRow.new(
            reference_fertilize_id: fertilize_id,
            name: name,
            n: 10,
            p: 5,
            k: 8,
            region: "jp"
          )
        end

        def build_interactor(read_gateway:, user_fertilize_gateway:, logger: nil, translator: nil)
          PlanSaveEnsureUserFertilizesInteractor.new(
            read_gateway: read_gateway,
            user_fertilize_gateway: user_fertilize_gateway,
            logger: logger || CapturingLogger.new,
            translator: translator || build_translator
          )
        end

        def default_input
          Dtos::PlanSaveEnsureUserFertilizesInput.new(user_id: 1, region: "jp")
        end

        test "creates user fertilize with copy suffix name" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_fertilize_reference_rows).with(region: "jp").returns(
            [ fertilize_row ]
          )
          read_gateway.expects(:exists_fertilize_name?).with(name: "肥料A (コピー)").returns(false)

          user_fertilize_gateway = mock("user_fertilize_gateway")
          user_fertilize_gateway.expects(:find_by_user_id_and_source_fertilize_id).with(
            user_id: 1,
            source_fertilize_id: 200
          ).returns(nil)
          user_fertilize_gateway.expects(:create).with(
            user_id: 1,
            attributes: has_entries(
              name: "肥料A (コピー)",
              source_fertilize_id: 200,
              is_reference: false
            )
          ).returns(Dtos::PlanSaveUserFertilizeSnapshot.new(id: 88, name: "肥料A (コピー)"))

          out = build_interactor(
            read_gateway: read_gateway,
            user_fertilize_gateway: user_fertilize_gateway
          ).call(default_input)

          assert_equal [ 88 ], out.user_fertilize_ids
          assert_empty out.skipped_fertilize_ids
        end

        test "reuses existing user fertilize and records skip" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_fertilize_reference_rows).returns([ fertilize_row ])

          user_fertilize_gateway = mock("user_fertilize_gateway")
          user_fertilize_gateway.expects(:find_by_user_id_and_source_fertilize_id).with(
            user_id: 1,
            source_fertilize_id: 200
          ).returns(Dtos::PlanSaveUserFertilizeSnapshot.new(id: 77, name: "既存肥料"))
          user_fertilize_gateway.expects(:create).never
          read_gateway.expects(:exists_fertilize_name?).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_fertilize_gateway: user_fertilize_gateway
          ).call(default_input)

          assert_equal [ 77 ], out.user_fertilize_ids
          assert_equal [ 77 ], out.skipped_fertilize_ids
        end

        test "second call with same row reuses existing and accumulates skipped_fertilize_ids" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_fertilize_reference_rows).twice.returns([ fertilize_row ])

          user_fertilize_gateway = mock("user_fertilize_gateway")
          user_fertilize_gateway.expects(:find_by_user_id_and_source_fertilize_id).twice.with(
            user_id: 1,
            source_fertilize_id: 200
          ).returns(Dtos::PlanSaveUserFertilizeSnapshot.new(id: 77, name: "既存肥料"))
          user_fertilize_gateway.expects(:create).never

          interactor = build_interactor(
            read_gateway: read_gateway,
            user_fertilize_gateway: user_fertilize_gateway
          )
          input = default_input

          out1 = interactor.call(input)
          out2 = interactor.call(input)

          assert_equal [ 77 ], out1.user_fertilize_ids
          assert_equal [ 77 ], out2.user_fertilize_ids
          assert_equal [ 77 ], out1.skipped_fertilize_ids
          assert_equal [ 77 ], out2.skipped_fertilize_ids
        end

        test "resolves unique name when first candidate is taken" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_fertilize_reference_rows).returns([ fertilize_row(name: "肥料B") ])
          read_gateway.expects(:exists_fertilize_name?).with(name: "肥料B (コピー)").returns(true)
          read_gateway.expects(:exists_fertilize_name?).with(name: "肥料B (コピー 2)").returns(false)

          user_fertilize_gateway = mock("user_fertilize_gateway")
          user_fertilize_gateway.expects(:find_by_user_id_and_source_fertilize_id).returns(nil)
          user_fertilize_gateway.expects(:create).with(
            user_id: 1,
            attributes: has_entries(
              name: "肥料B (コピー 2)",
              source_fertilize_id: 200,
              is_reference: false
            )
          ).returns(Dtos::PlanSaveUserFertilizeSnapshot.new(id: 90, name: "肥料B (コピー 2)"))

          out = build_interactor(
            read_gateway: read_gateway,
            user_fertilize_gateway: user_fertilize_gateway
          ).call(default_input)

          assert_equal [ 90 ], out.user_fertilize_ids
        end
      end
    end
  end
end
