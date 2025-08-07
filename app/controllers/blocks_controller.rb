class BlocksController < ApplicationController
  before_action :set_block, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  # skip_before_action :authenticate_user!

  # GET /blocks
  # GET /blocks.json
  def index
    @blocks = Block.all
  end

  # GET /blocks/1
  # GET /blocks/1.json
  def show
  end

  # GET /blocks/new
  def new
    @block = Block.new
  end

  # GET /blocks/1/edit
  def edit
  end

  # POST /blocks
  # POST /blocks.json
  def create
    @block = Block.new(block_params.except(:insertion_type))
    
    if @block.save
      # Handle position insertion based on insertion_type
      if params[:block][:position].present? && params[:block][:insertion_type].present?
        reference_position = params[:block][:position].to_i
        insertion_type = params[:block][:insertion_type]
        
        # Calculate new position based on insertion type
        new_position = insertion_type == 'above' ? reference_position : reference_position + 1
        
        # Insert at the calculated position (acts_as_list will handle reordering)
        @block.insert_at(new_position)
      end
      
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path) }
        format.json { render :show, status: :created, location: @block }
      end
    else
      respond_to do |format|
        format.html { render :show }
        format.json { render json: @block.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /blocks/1
  # PATCH/PUT /blocks/1.json
  def update
    respond_to do |format|
      if @block.update(block_params)
        format.html { redirect_back(fallback_location: root_path) }
        format.json { render :show, status: :ok, location: @block }
        format.js { head :no_content}
      else
        format.html { render :edit }
        format.json { render json: @block.errors, status: :unprocessable_entity }
        format.js { }
      end
    end
  end

  # DELETE /blocks/1
  # DELETE /blocks/1.json
  def destroy
    @block.destroy
    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path) }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_block
      @block = Block.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def block_params
      params.require(:block).permit(:cover_id, :font_size ,:font_family ,:content, :number, :remove_main_image, 
                                    :main_image, :bottom_padding, :id, :font_weight, :text_align, 
                                    :text_style, :image_block, :blank, :position, :insertion_type, other_images: [])
    end
end



