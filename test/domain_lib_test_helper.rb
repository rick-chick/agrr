# frozen_string_literal: true

# lib/domain を Rails なしで読み込み、ドメインロジックのみをテストする。
# lib/domain の AR / Data.define 混入は test/domain/lib_domain_no_active_record_references_test.rb が静的スキャンで検知する（docs/migration/lib-domain-rust/ARCHITECTURE.md）。
# 実行時に AR 定数を解決するコードパスは、Rails 未起動のため NameError 等で落ちる場合がある（Policy 直叩きはテストで stub されがち）。
#
# ActiveSupport に依存しない（core_ext / testing の require なし）。
# ※ `minitest/pride` は active_support を読み込むため domain-lib-test では使用しない。
# （ドメインコードに ActiveSupport 定数が紛れ込んでも検知できなくなる）
#
# 使い方（test/domain/* の先頭 require は本ファイルのみ。test_helper 禁止）:
#   .cursor/skills/test-common/scripts/run-test-domain-lib.sh [test/domain/...]  # ファイルまたはディレクトリ
#   bundle exec bin/domain-lib-test
#
ENV["RAILS_ENV"] ||= "test"

require "pathname"
require "bundler/setup"
require "logger"

ROOT = Pathname.new(__dir__).join("..").expand_path

unless defined?(Rails::Application) && Rails.application&.initialized?
  require "yaml"
  require "i18n"
  require "time"

  I18n.load_path.concat(Dir[ROOT.join("config/locales/**/*.yml").to_s].sort)
  I18n.backend.load_translations if I18n.backend.respond_to?(:load_translations)
  I18n.default_locale = :ja
  I18n.locale = :ja
end

require "zeitwerk"
require "bigdecimal"

module Domain; end unless defined?(Domain)

unless defined?(Rails::Application) && Rails.application&.initialized?
  loader = Zeitwerk::Loader.new
  loader.tag = "domain_standalone"
  loader.push_dir(ROOT.join("lib/domain"), namespace: Domain)

  loader.setup
end

require ROOT.join("test/support/capturing_logger").to_s
require ROOT.join("test/support/domain_lib_test_support").to_s

# Minitest が Gem の minitest/rails_plugin（railties）を読むと ActiveSupport が載る。
# domain-lib-test では `Minitest.run` 直前のプラグイン読込を抑止する（`--no-plugins` / MT_NO_PLUGINS と同じ）。
ENV["MT_NO_PLUGINS"] ||= "1"

require "minitest/autorun"
require "mocha/minitest"

# ActiveSupport なしで OpenStruct を使えるようにする
class OpenStruct
  def initialize(attrs = {})
    attrs.each { |k, v| instance_variable_set("@#{k}", v) }
  end

  def method_missing(name, *args)
    if args.empty?
      instance_variable_get("@#{name}")
    else
      raise NoMethodError, "undefined method `#{name}'"
    end
  end

  def respond_to_missing?(name, _include_private = false)
    true
  end
end

# ActiveSupport::Testing::Declarative の最小代替（test "説明" do ... end）
module DomainLibDeclarative
  def test(desc, &block)
    cleaned = desc.gsub(/\s+/, "_").gsub(/\W|^_+|_+$/, "").squeeze("_")
    cleaned = "noname" if cleaned.empty?
    base = :"test_#{cleaned}"
    method_name = base
    suffix = 2
    while method_defined?(method_name) || private_method_defined?(method_name)
      method_name = :"#{base}_#{suffix}"
      suffix += 1
    end
    define_method(method_name, &block)
  end
end

# ActiveSupport::Testing::SetupAndTeardown の最小代替（クラスレベル setup / teardown）
module DomainLibSetupTeardown
  def self.prepended(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def inherited(subclass)
      super
      subclass.instance_variable_set(:@domain_lib_setup_blocks, domain_lib_setup_blocks.dup)
      subclass.instance_variable_set(:@domain_lib_teardown_blocks, domain_lib_teardown_blocks.dup)
    end

    def domain_lib_setup_blocks
      @domain_lib_setup_blocks ||= []
    end

    def domain_lib_teardown_blocks
      @domain_lib_teardown_blocks ||= []
    end

    def setup(&block)
      domain_lib_setup_blocks << block
    end

    def teardown(&block)
      domain_lib_teardown_blocks << block
    end
  end

  DOMAIN_LIB_NO_ACTIVE_SUPPORT_MSG =
    "domain-lib-test は ActiveSupport を読み込んではいけません（ドメイン境界の検証のため）。".freeze

  def setup
    assert_nil defined?(ActiveSupport), DOMAIN_LIB_NO_ACTIVE_SUPPORT_MSG
    super
    self.class.domain_lib_setup_blocks.each { |block| instance_exec(&block) }
  end

  def teardown
    self.class.domain_lib_teardown_blocks.reverse_each { |block| instance_exec(&block) }
    super
  ensure
    assert_nil defined?(ActiveSupport), DOMAIN_LIB_NO_ACTIVE_SUPPORT_MSG
  end
end

class DomainLibTestCase < Minitest::Test
  include DomainLibTestSupport
  prepend DomainLibSetupTeardown
  extend DomainLibDeclarative

  # rails/test_help の assert_not 相当（素の Minitest には無い）
  def assert_not(test, msg = nil)
    refute test, msg
  end

  def assert_not_nil(obj, msg = nil)
    refute_nil obj, msg
  end
end
