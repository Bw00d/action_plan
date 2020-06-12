class CommoItemsController < ApplicationController
  before_action :set_commo_item, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  skip_before_action :authenticate_user!

  # GET /commo_items
  # GET /commo_items.json
  def index
    @commo_items = CommoItem.all
  end

  # GET /commo_items/1
  # GET /commo_items/1.json
  def show
  end

  # GET /commo_items/new
  def new
    @commo_item = CommoItem.new
  end

  # GET /commo_items/1/edit
  def edit
  end

  # POST /commo_items
  # POST /commo_items.json
  def create
    @commo_item = CommoItem.new(commo_item_params)

    respond_to do |format|
      if @commo_item.save
        format.html { redirect_back(fallback_location: root_path) }
        format.json { render :show, status: :created, location: @commo_item }
      else
        format.html { render :show }
        format.json { render json: @commo_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /commo_items/1
  # PATCH/PUT /commo_items/1.json
  def update
    @commo_item = CommoItem.find params[:id]

    respond_to do |format|
      if @commo_item.update_attributes(commo_item_params)
        format.html { redirect_back(fallback_location: root_path) }
        format.json { respond_with_bip(@commo_item) }
      else
        format.html { render :action => "show" }
        format.json { respond_with_bip(@commo_item) }
      end
    end
  end

  # DELETE /commo_items/1
  # DELETE /commo_items/1.json
  def destroy
    @commo_item.destroy
    respond_to do |format|
      format.html { redirect_to commo_items_url, notice: 'Commo item was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_commo_item
      @commo_item = CommoItem.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def commo_item_params
      params.require(:commo_item).permit(:zone, :ch_num, :function, :channel_name, :assignment, :rx_freq, :rx_tone, :tx_freq, :tx_tone, :mode, :commo_plan_id)
    end
end
