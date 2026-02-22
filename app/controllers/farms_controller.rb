# frozen_string_literal: true

class FarmsController < ApplicationController
  include DeletionUndoFlow
  before_action :set_farm, only: [:edit, :update, :destroy]

  # GET /farms
  def index
    respond_to do |format|
      format.html do
        input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: admin_user?)
        presenter = Presenters::Html::Farm::FarmListHtmlPresenter.new(view: self, is_admin: admin_user?)

        interactor = Domain::Farm::Interactors::FarmListInteractor.new(
          output_port: presenter,
          gateway: farm_gateway,
          user_id: current_user.id,
          translator: translator
        )

        interactor.call(input_dto)
      rescue StandardError => e
        redirect_to root_path, alert: e.message
      end

      format.json do
        if admin_user?
          # 管理者は自分の農場と参照農場の両方を表示
          @farms = current_user.farms.recent
          @reference_farms = Farm.reference
        else
          # 通常ユーザーは自分の農場のみ
          @farms = current_user.farms.recent
          @reference_farms = []
        end
        render json: { farms: @farms, reference_farms: @reference_farms }
      end
    end
  end

  # GET /farms/:id
  def show
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::Farm::FarmDetailHtmlPresenter.new(view: self)

        interactor = Domain::Farm::Interactors::FarmDetailInteractor.new(
          output_port: presenter,
          gateway: farm_gateway,
          user_id: current_user.id,
          translator: translator
        )

        interactor.call(params[:id])
      rescue Domain::Shared::Policies::PolicyPermissionDenied
        redirect_to farms_path, alert: I18n.t('farms.flash.not_found')
      rescue StandardError => e
        redirect_to farms_path, alert: e.message
      end

      format.json do
        render json: @farm
      end
    end
  end

  # GET /farms/new
  def new
    @farm = current_user.farms.build
  end

  # GET /farms/:id/edit
  def edit
    # Farm is already loaded by set_farm
  end

  # POST /farms
  def create
    respond_to do |format|
      format.html do
        @input_dto = Domain::Farm::Dtos::FarmCreateInputDto.from_hash({ farm: farm_params.to_h.symbolize_keys })
        presenter = Presenters::Html::Farm::FarmCreateHtmlPresenter.new(view: self)

        interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(
          output_port: presenter,
          gateway: farm_gateway,
          user_id: current_user.id,
          translator: translator
        )

        interactor.call(@input_dto)
      rescue StandardError => e
        @farm = current_user.farms.build(
          name: @input_dto.name,
          region: @input_dto.region,
          latitude: @input_dto.latitude,
          longitude: @input_dto.longitude
        )
        @farm.valid? # エラーをセットするためにバリデーションを実行
        flash.now[:alert] = e.message
        render :new, status: :unprocessable_entity
      end

      format.json do
        @farm = Domain::Shared::Policies::FarmPolicy.build_for_create(Farm, current_user, farm_params)

        if @farm.save
          Rails.logger.info "🎉 Farm created: ##{@farm.id} '#{@farm.name}' by user ##{current_user.id}"
          render json: @farm, status: :created
        else
          Rails.logger.warn "⚠️  Failed to create farm: #{@farm.errors.full_messages.join(', ')}"
          render json: { errors: @farm.errors }, status: :unprocessable_entity
        end
      end
    end
  end

  # PATCH/PUT /farms/:id
  def update
    respond_to do |format|
      format.html do
        @input_dto = Domain::Farm::Dtos::FarmUpdateInputDto.from_hash({ farm: farm_params.to_h.symbolize_keys }, params[:id])
        presenter = Presenters::Html::Farm::FarmUpdateHtmlPresenter.new(view: self)

        interactor = Domain::Farm::Interactors::FarmUpdateInteractor.new(
          output_port: presenter,
          gateway: farm_gateway,
          user_id: current_user.id,
          translator: translator
        )

        interactor.call(@input_dto)
      rescue StandardError => e
        @farm.assign_attributes(
          name: @input_dto.name,
          region: @input_dto.region,
          latitude: @input_dto.latitude,
          longitude: @input_dto.longitude
        )
        @farm.valid? # エラーをセットするためにバリデーションを実行
        flash.now[:alert] = e.message
        render :edit, status: :unprocessable_entity
      end

      format.json do
        update_result = @farm.update(farm_params)
        if update_result
          render json: @farm, status: :ok
        else
          render json: { errors: @farm.errors }, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /farms/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::Farm::FarmDestroyHtmlPresenter.new(view: self)

        interactor = Domain::Farm::Interactors::FarmDestroyInteractor.new(
          output_port: presenter,
          gateway: farm_gateway,
          user_id: current_user.id,
          translator: translator
        )

        interactor.call(params[:id])
      rescue Domain::Shared::Policies::PolicyPermissionDenied
        redirect_to farms_path, alert: I18n.t('farms.flash.not_found')
      end

      format.json do
        # API の destroy は既存の API コントローラに委譲するか、既存のロジックを使用
        if @farm.free_crop_plans.any?
          return render json: { error: I18n.t('farms.flash.cannot_delete', count: @farm.free_crop_plans.count) }, status: :unprocessable_entity
        end

        schedule_deletion_with_undo(
          record: @farm,
          toast_message: I18n.t('farms.undo.toast', name: @farm.display_name),
          fallback_location: Rails.application.routes.url_helpers.farms_path,
          in_use_message_key: nil,
          delete_error_message_key: 'farms.flash.delete_error'
        )
      rescue ActiveRecord::InvalidForeignKey => e
        message =
          if e.message.include?('cultivation_plans')
            I18n.t('farms.flash.cannot_delete_in_use.plan')
          elsif e.message.include?('fields')
            I18n.t('farms.flash.cannot_delete_in_use.field')
          else
            I18n.t('farms.flash.cannot_delete_in_use.other')
          end

        render json: { error: message }, status: :unprocessable_entity
      rescue ActiveRecord::DeleteRestrictionError
        render json: { error: I18n.t('farms.flash.cannot_delete_in_use.other') }, status: :unprocessable_entity
      end
    end
  end

  # View interface for HTML Presenters（Presenter から呼ばれるため public）
  def redirect_to(path, notice: nil, alert: nil)
    super(path, notice: notice, alert: alert)
  end

  def render_form(action, status: :ok, locals: {})
    render(action, status: status, locals: locals)
  end

  def undo_deletion_path(undo_token:)
    Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
  end

  def farm_path(farm)
    Rails.application.routes.url_helpers.farm_path(farm)
  end

  def farms_path
    Rails.application.routes.url_helpers.farms_path
  end

  private

  def set_farm
    if admin_user?
      # Admin can access any farm
      @farm = Farm.find(params[:id])
    else
      # Regular users can only access their own farms
      @farm = Domain::Shared::Policies::FarmPolicy.find_owned!(Farm, current_user, params[:id])
    end
  rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
    redirect_to farms_path, alert: I18n.t('farms.flash.not_found')
  end

  def farm_params
    permitted = [:name, :latitude, :longitude]

    # 管理者のみregionを許可
    permitted << :region if admin_user?

    params.require(:farm).permit(*permitted)
  end

  def farm_gateway
    @farm_gateway ||= Adapters::Farm::Gateways::FarmActiveRecordGateway.new
  end
end

