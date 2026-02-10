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
        
        # GET /api/v1/backdoor/users
        # Get list of users (excluding anonymous users)
        def users
          users = User.where(is_anonymous: false).order(created_at: :desc)
          
          user_data = users.map do |user|
            {
              id: user.id,
              email: user.email,
              name: user.name,
              google_id: user.google_id,
              admin: user.admin?,
              avatar_url: user.avatar_url,
              created_at: user.created_at.iso8601,
              updated_at: user.updated_at.iso8601,
              farms_count: user.farms.count,
              plans_count: user.cultivation_plans.count
            }
          end
          
          render json: {
            timestamp: Time.current.iso8601,
            total_users: users.count,
            users: user_data
          }
        end
        
        # POST /api/v1/backdoor/users
        # Create a new user
        def create_user
          user_params = user_create_params
          
          user = User.new(user_params)
          user.is_anonymous = false
          
          if user.save
            render json: {
              timestamp: Time.current.iso8601,
              success: true,
              user: {
                id: user.id,
                email: user.email,
                name: user.name,
                google_id: user.google_id,
                admin: user.admin?,
                avatar_url: user.avatar_url,
                created_at: user.created_at.iso8601,
                updated_at: user.updated_at.iso8601
              }
            }, status: :created
          else
            render json: {
              timestamp: Time.current.iso8601,
              success: false,
              errors: user.errors.full_messages
            }, status: :unprocessable_entity
          end
        end
        
        # PATCH/PUT /api/v1/backdoor/users/:id
        # Update an existing user
        def update_user
          user = User.find_by(id: params[:id])
          
          unless user
            render json: {
              timestamp: Time.current.iso8601,
              success: false,
              error: 'User not found'
            }, status: :not_found
            return
          end
          
          user_params = user_update_params
          
          if user.update(user_params)
            render json: {
              timestamp: Time.current.iso8601,
              success: true,
              user: {
                id: user.id,
                email: user.email,
                name: user.name,
                google_id: user.google_id,
                admin: user.admin?,
                avatar_url: user.avatar_url,
                created_at: user.created_at.iso8601,
                updated_at: user.updated_at.iso8601
              }
            }
          else
            render json: {
              timestamp: Time.current.iso8601,
              success: false,
              errors: user.errors.full_messages
            }, status: :unprocessable_entity
          end
        end
        
        # GET /api/v1/backdoor/db/stats
        # Get database statistics before clearing
        def db_stats
          stats = {
            users: User.where(is_anonymous: false).count,
            anonymous_users: User.where(is_anonymous: true).count,
            farms: Farm.count,
            fields: Field.count,
            crops: ::Crop.count,
            cultivation_plans: CultivationPlan.count,
            interaction_rules: InteractionRule.count,
            pesticides: Pesticide.count,
            pests: Pest.count,
            fertilizes: Fertilize.count,
            agricultural_tasks: AgriculturalTask.count,
            sessions: Session.count
          }
          
          render json: {
            timestamp: Time.current.iso8601,
            stats: stats,
            warning: '⚠️ Clearing database will delete ALL data except anonymous users'
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
              error: 'Missing confirmation_token parameter',
              warning: '⚠️ This operation will DELETE ALL DATA. Provide confirmation_token matching your backdoor token.'
            }, status: :bad_request
            return
          end
          
          unless confirmation_token == ::BackdoorConfig.token
            render json: {
              timestamp: Time.current.iso8601,
              success: false,
              error: 'Invalid confirmation_token',
              warning: 'confirmation_token must match your backdoor token for security'
            }, status: :forbidden
            return
          end
          
          # Log the dangerous operation
          Rails.logger.error "🚨 DANGEROUS OPERATION: Database clear requested via backdoor API at #{Time.current.iso8601}"
          Rails.logger.error "   Request IP: #{request.remote_ip}"
          Rails.logger.error "   User Agent: #{request.user_agent}"
          
          begin
            # Get stats before clearing
            before_stats = {
              users: User.where(is_anonymous: false).count,
              farms: Farm.count,
              fields: Field.count,
              crops: ::Crop.count,
              cultivation_plans: CultivationPlan.count
            }
            
            # Clear all data (except anonymous users)
            ActiveRecord::Base.transaction do
              # Delete in order to respect foreign key constraints
              Session.delete_all
              AgriculturalTask.delete_all
              Fertilize.delete_all
              Pest.delete_all
              Pesticide.delete_all
              InteractionRule.delete_all
              CultivationPlan.delete_all
              ::Crop.delete_all
              Field.delete_all
              Farm.delete_all
              User.where(is_anonymous: false).delete_all
            end
            
            after_stats = {
              users: User.where(is_anonymous: false).count,
              farms: Farm.count,
              fields: Field.count,
              crops: ::Crop.count,
              cultivation_plans: CultivationPlan.count
            }
            
            Rails.logger.error "✅ Database cleared successfully. Before: #{before_stats}, After: #{after_stats}"
            
            render json: {
              timestamp: Time.current.iso8601,
              success: true,
              message: 'Database cleared successfully',
              before_stats: before_stats,
              after_stats: after_stats,
              warning: '⚠️ All data has been deleted. This action is irreversible.'
            }
          rescue => e
            Rails.logger.error "❌ Error clearing database: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            
            render json: {
              timestamp: Time.current.iso8601,
              success: false,
              error: "Failed to clear database: #{e.message}"
            }, status: :internal_server_error
          end
        end
        
        private
        
        def check_backdoor_enabled
          unless ::BackdoorConfig.enabled?
            render json: {
              error: I18n.t('api.errors.backdoor.not_enabled'),
              error_key: 'api.errors.backdoor.not_enabled'
            }, status: :service_unavailable
            return
          end
        end
        
        def authenticate_backdoor_token
          provided_token = request.headers['X-Backdoor-Token'] || params[:token]
          
          unless provided_token.present?
            render json: {
              error: I18n.t('api.errors.backdoor.missing_token'),
              error_key: 'api.errors.backdoor.missing_token'
            }, status: :unauthorized
            return
          end
          
          unless provided_token == ::BackdoorConfig.token
            render json: {
              error: I18n.t('api.errors.backdoor.invalid_token'),
              error_key: 'api.errors.backdoor.invalid_token'
            }, status: :forbidden
            return
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

