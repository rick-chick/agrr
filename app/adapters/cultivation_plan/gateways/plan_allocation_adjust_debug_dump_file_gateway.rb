# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanAllocationAdjustDebugDumpFileGateway < Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpGateway
        def initialize(logger:, clock:, root_path:)
          @logger = logger
          @clock = clock
          @root_path = root_path
        end

        def dump_payload!(current_allocation:, moves:, fields:, crops:)
          debug_dir = @root_path.join("tmp/debug")
          FileUtils.mkdir_p(debug_dir)
          ts = @clock.now.to_i
          debug_current_allocation_path = debug_dir.join("adjust_current_allocation_#{ts}.json")
          debug_moves_path = debug_dir.join("adjust_moves_#{ts}.json")
          debug_fields_path = debug_dir.join("adjust_fields_#{ts}.json")
          debug_crops_path = debug_dir.join("adjust_crops_#{ts}.json")
          File.write(debug_current_allocation_path, JSON.pretty_generate(current_allocation))
          File.write(debug_moves_path, JSON.pretty_generate({ "moves" => moves }))
          File.write(debug_fields_path, JSON.pretty_generate({ "fields" => fields }))
          File.write(debug_crops_path, JSON.pretty_generate({ "crops" => crops }))
          @logger.info "📁 [Adjust] Debug current_allocation saved to: #{debug_current_allocation_path}"
          @logger.info "📁 [Adjust] Debug moves saved to: #{debug_moves_path}"
          @logger.info "📁 [Adjust] Debug fields saved to: #{debug_fields_path}"
          @logger.info "📁 [Adjust] Debug crops saved to: #{debug_crops_path}"
        end
      end
    end
  end
end
