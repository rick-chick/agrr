# frozen_string_literal: true

require "test_helper"

# Guards against re-introducing known use-case-encoding gateway method names.
# Patterns MUST match ARCHITECTURE.md § "Disallowed gateway public method name patterns".
class GatewayPublicMethodNamingTest < ActiveSupport::TestCase
  FORBIDDEN_NAME_PATTERNS = [
    /\Ainitialize_plan/,
    /\Afind_private_/,
    /\Afind_.*_bundle/,
    /\Alink_pest_to_crop/,
    /\Aupdate_pest_crop_associations/,
    /\Acopy_for_user_crops/,
    /\Asave_adjust_result!/,
    /\Aapply_field_cultivations/,
    /\Afind_or_create_/,
    /\Acopy_reference_stages/,
    /\Aagrr_rules_for_cultivation_plan_id/,
    /\Aoptimization_plan_snapshot/,
    /\Afind_private_cultivation_plan_detail/,
    /\Atask_schedule_timeline_snapshot/,
    /\Aprivate_plan_index_plan_rows/
  ].freeze

  test "adapter gateway public methods do not use forbidden use-case names" do
    violations = []

    Dir.glob(Rails.root.join("app/adapters/**/gateways/*_gateway.rb")).sort.each do |path|
      next if File.basename(path).start_with?("base_gateway")
      next if path.include?("/weather_data/gateways/")

      public_method_names(path).each do |name|
        FORBIDDEN_NAME_PATTERNS.each do |pattern|
          if name.match?(pattern)
            violations << "#{path.sub("#{Rails.root}/", '')}##{name} matches #{pattern.inspect}"
          end
        end
      end
    end

    assert_empty violations
  end

  def public_method_names(path)
    lines = File.readlines(path)
    names = []
    visibility = :public

    lines.each do |line|
      visibility = :private if line.match?(/^\s+private\s*$/)
      visibility = :protected if line.match?(/^\s+protected\s*$/)
      next unless visibility == :public

      if (m = line.match(/^\s+def ([a-z_][a-z0-9_!?]*)/))
        name = m[1]
        next if name == "initialize"

        names << name
      end
    end

    names
  end
end
