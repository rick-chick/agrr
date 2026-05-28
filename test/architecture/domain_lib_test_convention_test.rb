# frozen_string_literal: true

require "test_helper"
require Rails.root.join("test/support/domain_lib_test_convention.rb")

class DomainLibTestConventionTest < ActiveSupport::TestCase
  test "resolve_test_paths expands directory to nested domain test files" do
    root = Rails.root.to_s
    paths = DomainLibTestConvention.resolve_test_paths(root, ["test/domain/crop/policies"])

    assert paths.all? { |path| path.end_with?("_test.rb") }
    assert paths.all? { |path| path.start_with?(File.join(root, "test/domain/crop/policies")) }
    assert_includes paths, File.join(root, "test/domain/crop/policies/crop_reference_record_policy_test.rb")
    refute_empty paths
  end

  test "resolve_test_paths accepts file path" do
    root = Rails.root.to_s
    file = "test/domain/crop/policies/crop_reference_record_policy_test.rb"

    assert_equal [File.join(root, file)], DomainLibTestConvention.resolve_test_paths(root, [file])
  end

  test "resolve_test_paths deduplicates overlapping directory selections" do
    root = Rails.root.to_s
    paths = DomainLibTestConvention.resolve_test_paths(
      root,
      ["test/domain/crop/", "test/domain/crop/policies"]
    )

    assert_equal paths, paths.uniq
    assert_includes paths, File.join(root, "test/domain/crop/policies/crop_reference_record_policy_test.rb")
  end

  test "resolve_test_path_entry raises for missing path" do
    assert_raises(DomainLibTestConvention::MissingPathError) do
      DomainLibTestConvention.resolve_test_path_entry(Rails.root.to_s, "test/domain/no_such_path")
    end
  end

  test "resolve_test_path_entry raises for directory without domain tests" do
    empty_dir = Rails.root.join("tmp/domain_lib_test_convention_empty").tap(&:mkpath)

    assert_raises(DomainLibTestConvention::EmptyDirectoryError) do
      DomainLibTestConvention.resolve_test_path_entry(Rails.root.to_s, empty_dir.to_s)
    end
  ensure
    empty_dir.rmdir if empty_dir&.exist?
  end
end
