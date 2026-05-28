# frozen_string_literal: true

# test/domain/* の require 規約（Rails-free ハーネス）。
# bin/domain-lib-test と規約テストの双方から参照する。
module DomainLibTestConvention
  FORBIDDEN_PATTERNS = [
    /require\s+["']test_helper["']/,
    /require_relative\s+["'][^"']*test_helper/
  ].freeze

  REQUIRED_PATTERN = /require\s+["']domain_lib_test_helper["']/.freeze

  TEST_HELPER_BARRIER = <<~MSG.strip
    test/domain/* で require "test_helper"（または test_helper への require_relative）を検出しました。

    test_helper は config/environment・ActiveRecord・ActiveSupport・Rails テストスタックを読み込みます。
    lib/domain のユニットテスト（domain-lib）ではそれらを起動してはいけません。

    lib/domain に ActiveRecord / ActiveSupport / Rails 依存をテスト経路から注入しないこと。
    （ARCHITECTURE.md — lib/domain の Prohibited practices: Rails.*, AR クエリ, 環境時刻など）

    修正: 先頭を require "domain_lib_test_helper" に戻す。
    実行: .cursor/skills/test-common/scripts/run-test-domain-lib.sh
  MSG

  MISSING_HELPER_BARRIER = <<~MSG.strip
    test/domain/* には require "domain_lib_test_helper" が必須です（Rails-free ハーネス）。
  MSG

  module_function

  def forbidden_require_line?(line)
    FORBIDDEN_PATTERNS.any? { |pattern| line.match?(pattern) }
  end

  def all_domain_test_paths(root)
    Dir.glob(File.join(root, "test/domain/**/*_test.rb")).sort
  end

  # bin/domain-lib-test の引数（ファイルまたはディレクトリ）を *_test.rb の絶対パスへ展開する。
  def resolve_test_paths(root, entries)
    entries.flat_map { |entry| resolve_test_path_entry(root, entry) }.uniq.sort
  end

  def resolve_test_path_entry(root, entry)
    absolute = File.expand_path(entry, root)
    if File.directory?(absolute)
      matched = Dir.glob(File.join(absolute, "**", "*_test.rb")).sort
      raise EmptyDirectoryError, entry if matched.empty?

      matched
    elsif File.file?(absolute)
      [absolute]
    else
      raise MissingPathError, entry
    end
  end

  class PathResolutionError < StandardError
    attr_reader :entry

    def initialize(entry)
      @entry = entry
      super(entry)
    end
  end

  class MissingPathError < PathResolutionError; end
  class EmptyDirectoryError < PathResolutionError; end

  def scan(paths, root:)
    test_helper_violations = []
    missing_helper_violations = []

    paths.each do |path|
      rel = path.delete_prefix("#{root}/")
      require_lines = File.foreach(path).map { |line| line.sub(/#.*\z/, "").strip }.grep(/\Arequire(?:_relative)?\s+/)
      forbidden = require_lines.select { |line| forbidden_require_line?(line) }
      if forbidden.any?
        forbidden.each { |line| test_helper_violations << "#{rel}: #{line}" }
        next
      end
      next if require_lines.any? { |line| line.match?(REQUIRED_PATTERN) }

      missing_helper_violations << rel
    end

    { test_helper: test_helper_violations, missing_helper: missing_helper_violations }
  end

  def assert_ok!(paths, root:)
    result = scan(paths, root: root)
    return if result[:test_helper].empty? && result[:missing_helper].empty?

    sections = []

    unless result[:test_helper].empty?
      sections << <<~MSG

        ================================================================================
        domain-lib-test: BLOCKED — test_helper would inject Rails into lib/domain tests
        ================================================================================

        #{TEST_HELPER_BARRIER}

        Files:
        #{result[:test_helper].map { |l| "  - #{l}" }.join("\n")}
      MSG
    end

    unless result[:missing_helper].empty?
      sections << <<~MSG

        ================================================================================
        domain-lib-test: BLOCKED — missing domain_lib_test_helper
        ================================================================================

        #{MISSING_HELPER_BARRIER}

        Files:
        #{result[:missing_helper].map { |f| "  - #{f}" }.join("\n")}
      MSG
    end

    abort sections.join
  end
end
