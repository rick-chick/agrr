require "bundler/setup"
require "rspec"

ENV["RAILS_ENV"] ||= "test"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.disable_monkey_patching!

end
