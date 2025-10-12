class Admin::FarmSizesController < Admin::BaseController
  before_action :set_farm_size, only: %i[ show edit update destroy ]

  # GET /admin/farm_sizes or /admin/farm_sizes.json
  def index
    @farm_sizes = FarmSize.all
  end

  # GET /admin/farm_sizes/1 or /admin/farm_sizes/1.json
  def show
  end

  # GET /admin/farm_sizes/new
  def new
    @farm_size = FarmSize.new
  end

  # GET /admin/farm_sizes/1/edit
  def edit
  end

  # POST /admin/farm_sizes or /admin/farm_sizes.json
  def create
    @farm_size = FarmSize.new(farm_size_params)

    respond_to do |format|
      if @farm_size.save
        format.html { redirect_to [:admin, @farm_size], notice: "Farm size was successfully created." }
        format.json { render :show, status: :created, location: @farm_size }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @farm_size.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/farm_sizes/1 or /admin/farm_sizes/1.json
  def update
    respond_to do |format|
      if @farm_size.update(farm_size_params)
        format.html { redirect_to [:admin, @farm_size], notice: "Farm size was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @farm_size }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @farm_size.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/farm_sizes/1 or /admin/farm_sizes/1.json
  def destroy
    @farm_size.destroy!

    respond_to do |format|
      format.html { redirect_to admin_farm_sizes_path, notice: "Farm size was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_farm_size
      @farm_size = FarmSize.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def farm_size_params
      params.expect(farm_size: [ :name, :area_sqm, :display_order, :active ])
    end
end
