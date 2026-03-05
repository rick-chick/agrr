# frozen_string_literal: true

module Api
  module V1
    module Masters
      class FarmsController < BaseController
        include ApiCrudResponder
        include Views::Api::Farm::FarmListView
        include Views::Api::Farm::FarmDetailView
        include Views::Api::Farm::FarmCreateView
        include Views::Api::Farm::FarmUpdateView
        include Views::Api::Farm::FarmDeleteView

        private

        def farm_gateway
          @farm_gateway ||= Adapters::Farm::Gateways::FarmActiveRecordGateway.new
        end

        public

        # GET /api/v1/masters/farms
        def index
          input_valid?(:index) || return

          # DTO 変換
          input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: current_user&.admin?)

          # Interactor のインスタンス化と委譲
          presenter = Presenters::Api::Farm::FarmListPresenter.new(view: self)
          gateway = farm_gateway
          gateway.user_id = current_user.id
          interactor = Domain::Farm::Interactors::FarmListInteractor.new(
            output_port: presenter,
            gateway: gateway,
            user_id: current_user.id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new
          )
          interactor.call(input_dto)

          # Presenter の結果をチェック
          if instance_variable_defined?(:@farm_list_data) && @farm_list_data
            # 成功時: JSON を生成してレスポンス
            farms = @farm_list_data
            json = farms.is_a?(Array) ? farms.map { |e| entity_to_json(e) } : []
            render_response(json: json, status: :ok)
          elsif instance_variable_defined?(:@farm_list_error) && @farm_list_error
            # エラー時: エラーレスポンス
            msg = @farm_list_error.respond_to?(:message) ? @farm_list_error.message : @farm_list_error.to_s
            render_response(json: { error: msg }, status: :unprocessable_entity)
          end
        end

        # GET /api/v1/masters/farms/:id
        def show
          Rails.logger.info "Farm show action called with id: #{params[:id]}, current_user: #{current_user&.id}"

          input_valid?(:show) || return

          Rails.logger.info "Input validation passed"

          presenter = Presenters::Api::Farm::FarmDetailPresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmDetailInteractor.new(
            output_port: presenter,
            gateway: farm_gateway,
            user_id: current_user.id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new
          )

          Rails.logger.info "Calling interactor with farm_id: #{params[:id]}"
          interactor.call(params[:id])

          # Presenter の結果をチェック
          if instance_variable_defined?(:@farm_detail_data) && @farm_detail_data
            Rails.logger.info "Success: farm_detail_data present"
            # 成功時: JSON を生成してレスポンス
            farm_detail_dto = @farm_detail_data
            farm_json = entity_to_json(farm_detail_dto.farm)
            fields_json = farm_detail_dto.fields.map { |e| field_entity_to_json(e) }
            render_response(json: farm_json.merge(fields: fields_json), status: :ok)
          elsif instance_variable_defined?(:@farm_detail_error) && @farm_detail_error
            Rails.logger.info "Error: farm_detail_error present - #{@farm_detail_error}"
            # エラー時: エラーレスポンス
            msg = @farm_detail_error.respond_to?(:message) ? @farm_detail_error.message : @farm_detail_error.to_s
            render_response(json: { error: msg }, status: :not_found)
          else
            Rails.logger.warn "No data or error set by presenter"
            render_response(json: { error: 'Unknown error' }, status: :internal_server_error)
          end
        end

        # POST /api/v1/masters/farms
        def create
          input_dto = Domain::Farm::Dtos::FarmCreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_farm_params?(input_dto)
            render_response(json: { errors: ['name, region, latitude, longitude are required'] }, status: :unprocessable_entity)
            return
          end
          presenter = Presenters::Api::Farm::FarmCreatePresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(
            output_port: presenter,
            gateway: farm_gateway,
            user_id: current_user.id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new
          )
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/farms/:id
        def update
          input_dto = Domain::Farm::Dtos::FarmUpdateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Presenters::Api::Farm::FarmUpdatePresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmUpdateInteractor.new(
            output_port: presenter,
            gateway: farm_gateway,
            user_id: current_user.id,
            logger: logger_gateway,
            translator: translator
          )
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/farms/:id
        def destroy
          presenter = Presenters::Api::Farm::FarmDeletePresenter.new(view: self)
          interactor = Domain::Farm::Interactors::FarmDestroyInteractor.new(
            output_port: presenter,
            gateway: farm_gateway,
            user_id: current_user.id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            translator: translator,
            deletion_undo_gateway: deletion_undo_gateway
          )
          interactor.call(params[:id])

          # Presenter の結果をチェック
          if instance_variable_defined?(:@farm_delete_data) && @farm_delete_data
            # 成功時: undo 情報を含む JSON を生成してレスポンス
            undo_data = @farm_delete_data.undo
            undo_json = if undo_data
                          {
                            undo_token: undo_data.undo_token,
                            undo_path: undo_deletion_path(undo_token: undo_data.undo_token),
                            toast_message: @translator.t('flash.farms.deleted', name: @farm_delete_data.farm_name),
                            undo_deadline: undo_data.expires_at.iso8601,
                            auto_hide_after: 5000
                          }
                        else
                          nil
                        end
            Rails.logger.info("FarmController destroy response: #{ { undo: undo_json }.inspect }")
            render_response(json: { undo: undo_json }, status: :ok)
          elsif instance_variable_defined?(:@farm_delete_error) && @farm_delete_error
            # エラー時: エラーレスポンス
            msg = @farm_delete_error.respond_to?(:message) ? @farm_delete_error.message : @farm_delete_error.to_s
            render_response(json: { error: msg }, status: :unprocessable_entity)
          end
        end

        # View の実装: render は controller.render への委譲のみ
        def render_response(json:, status:)
          render(json: json, status: status)
        end

        # FarmDeleteView: undo 用 JSON の undo_path 組み立て
        def undo_deletion_path(undo_token:)
          Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
        end

        private

        def farm_gateway
          @farm_gateway ||= Adapters::Farm::Gateways::FarmActiveRecordGateway.new
        end

        def deletion_undo_gateway
          @deletion_undo_gateway ||= Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
        end

        def resource_dom_id_for(event)
          stored = event.metadata['resource_dom_id']
          return stored if stored.present?

          [event.resource_type.demodulize.underscore, event.resource_id].join('_')
        end

        def entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            latitude: entity.latitude,
            longitude: entity.longitude,
            region: entity.region,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at,
            is_reference: entity.is_reference
          }
        end

        def field_entity_to_json(entity)
          {
            id: entity.id,
            name: entity.name,
            area: entity.area,
            daily_fixed_cost: entity.daily_fixed_cost,
            region: entity.region,
            farm_id: entity.farm_id,
            user_id: entity.user_id,
            created_at: entity.created_at,
            updated_at: entity.updated_at
          }
        end

        def input_valid?(action)
          case action
          when :show, :destroy
            return true if params[:id].present?
            render_response(json: { error: 'Farm not found' }, status: :not_found)
            false
          else
            true
          end
        end

        def valid_farm_params?(input_dto)
          input_dto.name.present? && input_dto.region.present? &&
            !input_dto.latitude.nil? && !input_dto.longitude.nil?
        end

        def logger_gateway
          @logger_gateway ||= Adapters::Logger::Gateways::RailsLoggerGateway.new
        end

        def translator
          @translator ||= Adapters::Translators::RailsTranslator.new
        end

      end
    end
  end
end
