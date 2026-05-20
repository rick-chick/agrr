# frozen_string_literal: true

require "domain_lib_test_helper"
require "open3"

class DomainLibHarnessActiveSupportRegressionTest < DomainLibTestCase
  PROJECT_ROOT = Pathname.new(__dir__).join("..", "..").expand_path
  HELPER = PROJECT_ROOT.join("test/domain_lib_test_helper.rb")

  # サブプロセスで domain_lib_test_helper を load した直後に Kernel.exit! すると
  # minitest/autorun の at_exit が走らず、終了コードだけで AS 未ロードを検証できる。

  test "domain_lib_test_helper load does not load ActiveSupport (subprocess)" do
    script = <<~RUBY
      $LOAD_PATH.unshift(#{PROJECT_ROOT.join("lib").to_s.dump}, #{PROJECT_ROOT.join("test").to_s.dump})
      load #{HELPER.to_s.dump}
      exit!(defined?(ActiveSupport) ? 1 : 0)
    RUBY
    _out, err, status = Open3.capture3(Gem.ruby, "-W:deprecated", "-e", script)
    assert_equal 0, status.exitstatus,
      "ActiveSupport must not load during domain_lib_test_helper load ((stderr): #{err})"
  end

  test "referencing ActiveSupport constant without loading it raises NameError (subprocess)" do
    script = <<~RUBY
      $LOAD_PATH.unshift(#{PROJECT_ROOT.join("lib").to_s.dump}, #{PROJECT_ROOT.join("test").to_s.dump})
      load #{HELPER.to_s.dump}
      begin
        case "bogus"
        when Time, ActiveSupport::TimeWithZone
        end
        exit!(1)
      rescue NameError
        exit!(0)
      end
    RUBY
    _out, err, status = Open3.capture3(Gem.ruby, "-W:deprecated", "-e", script)
    assert_equal 0, status.exitstatus,
      "Domain-style ActiveSupport reference must fail fast without AS loaded ((stderr): #{err})"
  end

  test "DomainLibTestCase setup fails when ActiveSupport was loaded first (subprocess)" do
    script = <<~RUBY
      $LOAD_PATH.unshift(#{PROJECT_ROOT.join("lib").to_s.dump}, #{PROJECT_ROOT.join("test").to_s.dump})
      load #{HELPER.to_s.dump}
      require "active_support"
      klass = Class.new(DomainLibTestCase) do
        def test_dummy
          assert true
        end
      end
      result = klass.new("test_dummy").run
      exit!(result.failures.empty? ? 1 : 0)
    RUBY
    _out, err, status = Open3.capture3(Gem.ruby, "-W:deprecated", "-e", script)
    assert_equal 0, status.exitstatus,
      "DomainLibTestCase must fail when AS is loaded ((stderr): #{err})"
  end
end
