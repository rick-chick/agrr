# frozen_string_literal: true

# When set, JSON API / ActionCable / OAuth are served only by agrr-server (no Rails handlers).
module AgrrRustApi
  module_function

  def enabled?
    ENV["AGRR_RUST_API"] == "1"
  end
end
