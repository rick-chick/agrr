# frozen_string_literal: true

# Legacy hook for tests that called stub_all_agrr_commands. Agrr I/O is exercised on agrr-server (Rust).
module AgrrMockHelper
  def stub_all_agrr_commands
    # no-op
  end
end
