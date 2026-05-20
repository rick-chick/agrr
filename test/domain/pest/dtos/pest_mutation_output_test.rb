# frozen_string_literal: true

require "domain_lib_test_helper"

class PestMutationOutputTest < DomainLibTestCase
  test "carries status and optional entity lists" do
    dto = Domain::Pest::Dtos::PestMutationOutput.new(status: :created)
    assert_equal :created, dto.status
    assert_nil dto.pest_entity
    assert_empty dto.unassociated_pest_entities
    assert_nil dto.crop_nest_snapshot
  end
end
