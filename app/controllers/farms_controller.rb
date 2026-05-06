# frozen_string_literal: true

class FarmsController < ApplicationController
  before_action :load_farm_for_edit, only: [ :edit, :update, :destroy ]

  # GET /farms
  def index
    respond_to do |format|
      format.html do
        input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: admin_user?)
        presenter = Presenters::Html::Farm::FarmListHtmlPresenter.new(view: self)

        interactor = Domain::Farm::Interactors::FarmListRowsBundleInteractor.new(
          output_port: presenter,
          user_id: current_user.id,
          gateway: CompositionRoot.farm_gateway
        )

        interactor.call(input_dto)
      end

      format.json do
        input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: admin_user?)
        presenter = Presenters::Html::Farm::FarmListJsonPresenter.new(view: self)
        Domain::Farm::Interactors::FarmListInteractor.new(
          output_port: presenter,
          user_id: current_user.id,
          gateway: CompositionRoot.farm_gateway,
          logger: CompositionRoot.logger,
          translator: CompositionRoot.translator
        ).call(input_dto)
      end
    end
  end

  # GET /farms/:id
  def show
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::Farm::FarmDetailHtmlPresenter.new(view: self)

        interactor = Domain::Farm::Interactors::FarmDetailInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup)

        interactor.call(params[:id])
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

        interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup)

        interactor.call(@input_dto)
      end

      format.json do
        presenter = Presenters::Html::Farm::FarmDirectJsonCreatePresenter.new(view: self)
        input_dto = Domain::Farm::Dtos::FarmCreateInputDto.from_hash({ farm: farm_params.to_h.symbolize_keys })
        Domain::Farm::Interactors::FarmCreateInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call(input_dto)
      end
    end
  end

  # PATCH/PUT /farms/:id
  def update
    respond_to do |format|
      format.html do
        @input_dto = Domain::Farm::Dtos::FarmUpdateInputDto.from_hash({ farm: farm_params.to_h.symbolize_keys }, params[:id])
        presenter = Presenters::Html::Farm::FarmUpdateHtmlPresenter.new(view: self)

        interactor = Domain::Farm::Interactors::FarmUpdateInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup)

        interactor.call(@input_dto)
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

        interactor = Domain::Farm::Interactors::FarmDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup)

        interactor.call(params[:id])
      end

      format.json do
        # API の destroy は既存の API コントローラに委譲するか、既存のロジックを使用
        if @farm.free_crop_plans.any?
          return render json: { error: I18n.t("farms.flash.cannot_delete", count: @farm.free_crop_plans.count) }, status: :unprocessable_entity
        end

        DeletionUndo::HtmlMasterScheduleInvoker.call(
          view: self,
          actor_id: current_user.id,
          record: @farm,
          toast_message: I18n.t("farms.undo.toast", name: @farm.display_name),
          fallback_location: Rails.application.routes.url_helpers.farms_path,
          in_use_message_key: nil,
          delete_error_message_key: "farms.flash.delete_error"
        )
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

  # FarmListJsonPresenter など JSON 用 Presenter が参照する View インターフェース
  def render_response(json:, status:)
    render(json: json, status: status)
  end

  private

  def load_farm_for_edit
    presenter = Presenters::Html::Farm::FarmLoadForEditHtmlPresenter.new(view: self)
    Domain::Farm::Interactors::FarmLoadAuthorizedModelForEditInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.farm_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  def farm_params
    permitted = [ :name, :latitude, :longitude ]

    # 管理者のみregionを許可
    permitted << :region if admin_user?

    params.require(:farm).permit(*permitted)
  end

end
