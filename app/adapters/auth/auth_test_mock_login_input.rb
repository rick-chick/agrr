# frozen_string_literal: true

module Adapters
  module Auth
    # Dev/test mock login input (OmniAuth hash → session cookie).
    class AuthTestMockLoginInput
      attr_reader :google_id, :email, :name, :avatar_source_url, :grant_admin,
                  :stashed_public_plan, :pending_return_to, :pending_return_to_allowed

      def initialize(google_id:, email:, name:, avatar_source_url:, grant_admin:,
                     stashed_public_plan:, pending_return_to:, pending_return_to_allowed:)
        @google_id = google_id.to_s
        @email = email.to_s
        @name = name.to_s
        @avatar_source_url = avatar_source_url.to_s
        @grant_admin = grant_admin ? true : false
        @stashed_public_plan = stashed_public_plan ? true : false
        @pending_return_to = pending_return_to&.to_s&.strip
        @pending_return_to_allowed = pending_return_to_allowed ? true : false
      end
    end
  end
end
