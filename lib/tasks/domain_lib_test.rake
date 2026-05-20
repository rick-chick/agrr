# frozen_string_literal: true

namespace :test do
  desc "lib/domain のユニットテストを Rails スタックなしで実行（bin/domain-lib-test と同等）"
  task :domain_lib do
    root = Rails.root
    script = root.join("bin/domain-lib-test")
    exec(script.to_s)
  end
end
