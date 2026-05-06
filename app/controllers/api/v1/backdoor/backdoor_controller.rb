# frozen_string_literal: true

module Api
  module V1
    module Backdoor
      # Backdoor API for AGRR daemon status monitoring
      # Uses random token authentication for security
      class BackdoorController < ApplicationController
        skip_before_action :verify_authenticity_token
        skip_before_action :authenticate_user!

        before_action :check_backdoor_enabled
        before_action :authenticate_backdoor_token

        # GET /api/v1/backdoor/status
        # Check AGRR daemon status
        def status
          agrr_bin = Rails.root.join("lib", "core", "agrr")
          socket_path = "/tmp/agrr.sock"

          # Check if binary exists
          binary_exists = File.exist?(agrr_bin)
          binary_executable = binary_exists && File.executable?(agrr_bin)

          # Check if daemon is running
          daemon_running = File.exist?(socket_path) && File.socket?(socket_path)

          # Get daemon status from agrr command
          daemon_status_output = nil
          daemon_pid = nil

          if binary_executable
            shell = CompositionRoot.backdoor_shell_stdout_capture_gateway
            daemon_status_output = shell.capture("#{agrr_bin} daemon status 2>&1")
            if daemon_status_output.present?
              if match = daemon_status_output.match(/PID[:\s]+(\d+)/i)
                daemon_pid = match[1].to_i
              end
            end
          end

          # Get process information
          process_info = nil
          if daemon_pid
            shell = CompositionRoot.backdoor_shell_stdout_capture_gateway
            rss_out = shell.capture("ps -o rss= -p #{daemon_pid}")
            etime_out = shell.capture("ps -o etime= -p #{daemon_pid}")
            if rss_out.present? && etime_out.present?
              memory_kb = rss_out.to_i
              memory_mb = (memory_kb / 1024.0).round(2)
              process_info = {
                pid: daemon_pid,
                memory_mb: memory_mb,
                uptime: etime_out.strip
              }
            end
          end

          render json: {
            timestamp: Time.current.iso8601,
            daemon: {
              running: daemon_running,
              socket_exists: File.exist?(socket_path),
              socket_path: socket_path
            },
            binary: {
              exists: binary_exists,
              executable: binary_executable,
              path: agrr_bin.to_s
            },
            status_output: daemon_status_output,
            process: process_info,
            service_available: daemon_running && binary_executable
          }
        end

        # GET /api/v1/backdoor/health
        # Simple health check endpoint
        def health
          render json: {
            status: "ok",
            timestamp: Time.current.iso8601,
            message: "Backdoor API is active"
          }
        end

        # GET /api/v1/backdoor/users
        # Get list of users (excluding anonymous users)
        def users
          payload = CompositionRoot.backdoor_diagnostics_gateway.users_list_payload
          render json: {
            timestamp: Time.current.iso8601,
            total_users: payload[:total_users],
            users: payload[:users]
          }
        end

        # POST /api/v1/backdoor/users
        # Create a new user
        def create_user
          user_params = user_create_params
          result = CompositionRoot.backdoor_diagnostics_gateway.create_user(user_params.to_h.symbolize_keys)

          if result[:ok]
            render json: {
              timestamp: Time.current.iso8601,
              success: true,
              user: result[:user]
            }, status: :created
          else
            render json: {
              timestamp: Time.current.iso8601,
              success: false,
              errors: result[:errors]
            }, status: :unprocessable_entity
          end
        end

        # PATCH/PUT /api/v1/backdoor/users/:id
        # Update an existing user
        def update_user
          result = CompositionRoot.backdoor_diagnostics_gateway.update_user(params[:id], user_update_params.to_h.symbolize_keys)

          if result[:ok]
            render json: {
              timestamp: Time.current.iso8601,
              success: true,
              user: result[:user]
            }
          elsif result[:error] == :not_found
            render json: {
              timestamp: Time.current.iso8601,
              success: false,
              error: "User not found"
            }, status: :not_found
          else
            render json: {
              timestamp: Time.current.iso8601,
              success: false,
              errors: result[:errors]
            }, status: :unprocessable_entity
          end
        end

        # GET /api/v1/backdoor/db/stats
        # Get database statistics before clearing
        def db_stats
          stats = CompositionRoot.backdoor_diagnostics_gateway.db_stats_counts

          render json: {
            timestamp: Time.current.iso8601,
            stats: stats,
            warning: "⚠️ Clearing database will delete ALL data except anonymous users"
          }
        end

        # POST /api/v1/backdoor/db/clear
        # ⚠️ DANGEROUS: Clear all data from production database
        # Requires confirmation_token parameter matching the backdoor token
        def clear_db
          confirmation_token = params[:confirmation_token]

          unless confirmation_token.present?
            render json: {
              timestamp: Time.current.iso8601,
              success: false,
              error: "Missing confirmation_token parameter",
              warning: "⚠️ This operation will DELETE ALL DATA. Provide confirmation_token matching your backdoor token."
            }, status: :bad_request
            return
          end

          unless confirmation_token == ::BackdoorConfig.token
            render json: {
              timestamp: Time.current.iso8601,
              success: false,
              error: "Invalid confirmation_token",
              warning: "confirmation_token must match your backdoor token for security"
            }, status: :forbidden
            return
          end

          # Log the dangerous operation
          Rails.logger.error "🚨 DANGEROUS OPERATION: Database clear requested via backdoor API at #{Time.current.iso8601}"
          Rails.logger.error "   Request IP: #{request.remote_ip}"
          Rails.logger.error "   User Agent: #{request.user_agent}"

          presenter = Presenters::Api::Backdoor::BackdoorClearDatabasePresenter.new(view: self)
          Domain::Backdoor::Interactors::BackdoorClearDatabaseInteractor.new(
            output_port: presenter,
            gateway: CompositionRoot.backdoor_application_database_clear_gateway,
            logger: CompositionRoot.logger
          ).call
        end

        def render_response(json:, status:)
          render(json: json, status: status)
        end

        private

        def check_backdoor_enabled
          unless ::BackdoorConfig.enabled?
            render json: {
              error: I18n.t("api.errors.backdoor.not_enabled"),
              error_key: "api.errors.backdoor.not_enabled"
            }, status: :service_unavailable
            nil
          end
        end

        def authenticate_backdoor_token
          provided_token = request.headers["X-Backdoor-Token"] || params[:token]

          unless provided_token.present?
            render json: {
              error: I18n.t("api.errors.backdoor.missing_token"),
              error_key: "api.errors.backdoor.missing_token"
            }, status: :unauthorized
            return
          end

          unless provided_token == ::BackdoorConfig.token
            render json: {
              error: I18n.t("api.errors.backdoor.invalid_token"),
              error_key: "api.errors.backdoor.invalid_token"
            }, status: :forbidden
            nil
          end
        end

        def user_create_params
          params.require(:user).permit(:email, :name, :google_id, :avatar_url, :admin)
        end

        def user_update_params
          params.require(:user).permit(:email, :name, :google_id, :avatar_url, :admin)
        end
      end
    end
  end
end
