class FreqsController < ApplicationController
  before_action :set_freq, only: [:show, :edit, :update, :destroy]

  # GET /freqs
  # GET /freqs.json
  def index
    @freqs = Freq.all
  end

  # GET /freqs/1
  # GET /freqs/1.json
  def show
  end

  # GET /freqs/new
  def new
    @freq = Freq.new
  end

  # GET /freqs/1/edit
  def edit
  end

  # POST /freqs
  # POST /freqs.json
  def create
    @freq = Freq.new(freq_params)

    respond_to do |format|
      if @freq.save
        format.html { redirect_to @freq, notice: 'Freq was successfully created.' }
        format.json { render :show, status: :created, location: @freq }
      else
        format.html { render :new }
        format.json { render json: @freq.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /freqs/1
  # PATCH/PUT /freqs/1.json
  def update
    respond_to do |format|
      if @freq.update(freq_params)
        format.html { redirect_to @freq, notice: 'Freq was successfully updated.' }
        format.json { render :show, status: :ok, location: @freq }
      else
        format.html { render :edit }
        format.json { render json: @freq.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /freqs/1
  # DELETE /freqs/1.json
  def destroy
    @freq.destroy
    respond_to do |format|
      format.html { redirect_to freqs_url, notice: 'Freq was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_freq
      @freq = Freq.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def freq_params
      params.require(:freq).permit(:assignment_id, :commo_item_id)
    end
end
