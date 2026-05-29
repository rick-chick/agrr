# frozen_string_literal: true

require "test_helper"
require "net/http"

# R4 contract harness (P6). Runs against Rails by default; set CONTRACT_RUNTIME=rust
# and RUST_CONTRACT_BASE_URL=http://127.0.0.1:8080 to assert on agrr-server.
# Co-located rust runs: scripts/run-rust-contract-tests.sh (same SQLite as test DB).
class ContractTestCase < ActionDispatch::IntegrationTest
  # Separate SQLite connections (agrr-server) cannot see uncommitted AR test transactions.
  self.use_transactional_tests = false if ENV.fetch("CONTRACT_RUNTIME", "rails") == "rust"

  def contract_runtime
    ENV.fetch("CONTRACT_RUNTIME", "rails")
  end

  def rust_contract?
    contract_runtime == "rust"
  end

  def contract_host
    ENV.fetch("RUST_CONTRACT_BASE_URL", "http://127.0.0.1:8080").chomp("/")
  end

  # Path to the DB file the running Rails test process uses (for agrr-server AGRR_SQLITE_PATH).
  def rust_sqlite_path
    ActiveRecord::Base.connection_db_config.database
  end

  # Session expiry must exceed SQLite `datetime('now')` when tests use `travel_to` in the past.
  def contract_session_id_for(user)
    session = Session.create_for_user(user)
    session.update_column(:expires_at, Time.utc(2099, 1, 1))
    session.session_id
  end

  def rust_get(path, session_id: nil, headers: {}, accept: "application/json")
    uri = URI("#{contract_host}#{path}")
    req = Net::HTTP::Get.new(uri)
    req["Accept"] = accept
    req["Cookie"] = "session_id=#{session_id}" if session_id
    headers.each { |key, value| req[key] = value }
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  end

  def rust_post(path, session_id: nil, body: nil, headers: {}, accept: "application/json")
    uri = URI("#{contract_host}#{path}")
    req = Net::HTTP::Post.new(uri)
    req["Accept"] = accept
    req["Content-Type"] = "application/json"
    req["Cookie"] = "session_id=#{session_id}" if session_id
    headers.each { |key, value| req[key] = value }
    req.body = body.is_a?(String) ? body : body.to_json if body
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  end

  def rust_patch(path, session_id: nil, body: nil, headers: {}, accept: "application/json")
    uri = URI("#{contract_host}#{path}")
    req = Net::HTTP::Patch.new(uri)
    req["Accept"] = accept
    req["Content-Type"] = "application/json"
    req["Cookie"] = "session_id=#{session_id}" if session_id
    headers.each { |key, value| req[key] = value }
    req.body = body.is_a?(String) ? body : body.to_json if body
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  end

  def rust_delete(path, session_id: nil, accept: "application/json")
    uri = URI("#{contract_host}#{path}")
    req = Net::HTTP::Delete.new(uri)
    req["Accept"] = accept
    req["Cookie"] = "session_id=#{session_id}" if session_id
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  end
end
