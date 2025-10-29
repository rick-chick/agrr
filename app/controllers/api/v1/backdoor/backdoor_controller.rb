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
          agrr_bin = Rails.root.join('lib', 'core', 'agrr')
          socket_path = '/tmp/agrr.sock'
          
          # Check if binary exists
          binary_exists = File.exist?(agrr_bin)
          binary_executable = binary_exists && File.executable?(agrr_bin)
          
          # Check if daemon is running
          daemon_running = File.exist?(socket_path) && File.socket?(socket_path)
          
          # Get daemon status from agrr command
          daemon_status_output = nil
          daemon_pid = nil
          
          if binary_executable
            begin
              daemon_status_output = `#{agrr_bin} daemon status 2>&1`.strip
              # Try to extract PID from output
              if match = daemon_status_output.match(/PID[:\s]+(\d+)/i)
                daemon_pid = match[1].to_i
              end
            rescue => e
              Rails.logger.error "Error checking daemon status: #{e.message}"
            end
          end
          
          # Get process information
          process_info = nil
          if daemon_pid
            begin
              # Get memory usage
              memory_kb = `ps -o rss= -p #{daemon_pid}`.to_i
              memory_mb = (memory_kb / 1024.0).round(2)
              
              # Get uptime
              uptime_seconds = `ps -o etime= -p #{daemon_pid}`.to_s.strip
              process_info = {
                pid: daemon_pid,
                memory_mb: memory_mb,
                uptime: uptime_seconds
              }
            rescue => e
              Rails.logger.error "Error getting process info: #{e.message}"
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
            status: 'ok',
            timestamp: Time.current.iso8601,
            message: 'Backdoor API is active'
          }
        end
        
        private
        
        def check_backdoor_enabled
          unless ::BackdoorConfig.enabled?
            render json: { error: 'Backdoor is not enabled. Set AGRR_BACKDOOR_TOKEN environment variable.' }, status: :service_unavailable
            return
          end
        end
        
        def authenticate_backdoor_token
          provided_token = request.headers['X-Backdoor-Token'] || params[:token]
          
          unless provided_token.present?
            render json: { error: 'Missing authentication token' }, status: :unauthorized
            return
          end
          
          unless provided_token == ::BackdoorConfig.token
            render json: { error: 'Invalid authentication token' }, status: :forbidden
            return
          end
        end
      end
    end
  end
end

