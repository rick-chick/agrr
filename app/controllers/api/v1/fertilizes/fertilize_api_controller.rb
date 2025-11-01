# frozen_string_literal: true

class Api::V1::Fertilizes::FertilizeApiController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_interactors

  # GET /api/v1/fertilizes
  def index
    # データベースから参照肥料を取得
    fertilizes = @find_all_interactor.call
    
    if fertilizes.success?
      render json: fertilizes.data.map { |fertilize| fertilize_to_json(fertilize) }
    else
      render json: { error: fertilizes.error }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/fertilizes/:id
  def show
    result = @find_interactor.call(params[:id])
    
    if result.success?
      render json: fertilize_to_json(result.data)
    else
      render json: { error: result.error }, status: :not_found
    end
  end

  # POST /api/v1/fertilizes
  def create
    result = @create_interactor.call(fertilize_params)
    
    if result.success?
      render json: fertilize_to_json(result.data), status: :created
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/fertilizes/:id
  def update
    result = @update_interactor.call(params[:id], fertilize_params)
    
    if result.success?
      render json: fertilize_to_json(result.data)
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/fertilizes/:id
  def destroy
    result = @delete_interactor.call(params[:id])
    
    if result.success?
      head :no_content
    else
      # エラーメッセージに応じて適切なHTTPステータスコードを返す
      if result.error.include?("使用されているため削除できません")
        render json: { error: result.error }, status: :conflict
      else
        render json: { error: result.error }, status: :not_found
      end
    end
  end

  private

  def set_interactors
    fertilize_gateway = Adapters::Fertilize::Gateways::FertilizeMemoryGateway.new
    
    @create_interactor = Domain::Fertilize::Interactors::FertilizeCreateInteractor.new(fertilize_gateway)
    @find_interactor = Domain::Fertilize::Interactors::FertilizeFindInteractor.new(fertilize_gateway)
    @update_interactor = Domain::Fertilize::Interactors::FertilizeUpdateInteractor.new(fertilize_gateway)
    @delete_interactor = Domain::Fertilize::Interactors::FertilizeDeleteInteractor.new(fertilize_gateway)
    @find_all_interactor = Domain::Fertilize::Interactors::FertilizeFindAllInteractor.new(fertilize_gateway)
  end

  def fertilize_params
    params.require(:fertilize).permit(:name, :n, :p, :k, :description, :usage, :application_rate, :package_size, :is_reference)
  end

  def fertilize_to_json(fertilize)
    {
      id: fertilize.id,
      name: fertilize.name,
      n: fertilize.n,
      p: fertilize.p,
      k: fertilize.k,
      description: fertilize.description,
      usage: fertilize.usage,
      application_rate: fertilize.application_rate,
      package_size: fertilize.package_size,
      is_reference: fertilize.is_reference,
      npk_summary: fertilize.npk_summary,
      created_at: fertilize.created_at,
      updated_at: fertilize.updated_at
    }
  end
end

