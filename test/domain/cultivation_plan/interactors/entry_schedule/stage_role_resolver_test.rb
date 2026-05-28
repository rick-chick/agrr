# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      module EntrySchedule
        class StageRoleResolverTest < DomainLibTestCase
          TempReq = Struct.new(
            :frost_threshold,
            :optimal_min,
            :optimal_max,
            :base_temperature,
            keyword_init: true
          )

          def stage(id, name, order)
            CropStageSnapshot.new(
              id: id,
              name: name,
              order: order,
              temperature_requirement: TempReq.new(
                optimal_min: 10.0,
                optimal_max: 20.0,
                base_temperature: 5.0
              )
            )
          end

          test "sowing_stage returns minimum order" do
            stages = [ stage(2, "生育", 2), stage(1, "播種", 1) ]
            sow = StageRoleResolver.sowing_stage(stages)
            assert_equal 1, sow.id
            assert_equal "播種", sow.name
          end

          test "transplant_stage prefers name with transplant pattern" do
            stages = [
              stage(1, "播種", 1),
              stage(2, "定植", 2),
              stage(3, "収穫", 3)
            ]
            tr = StageRoleResolver.transplant_stage(stages)
            assert_equal 2, tr.id
          end

          test "transplant_stage falls back to second ordered stage" do
            stages = [ stage(1, "播種", 1), stage(2, "生育", 2) ]
            tr = StageRoleResolver.transplant_stage(stages)
            assert_equal 2, tr.id
          end
        end
      end
    end
  end
end
