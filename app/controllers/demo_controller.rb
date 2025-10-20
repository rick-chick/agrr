# frozen_string_literal: true

# Demo controller for testing UI components
class DemoController < ApplicationController
  # Skip authentication for demo purposes
  skip_before_action :require_login, only: [:ui_system]

  def ui_system
    # Render demo page for UI System
  end
end

