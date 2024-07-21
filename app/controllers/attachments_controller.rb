class AttachmentsController < ApplicationController
  before_action :set_attachment, only: %i[ update destroy ]

  include SkipAuthorization
  # skip_before_action :authenticate_user!

  # GET /attachments or /attachments.json
  def index
    @attachments = Attachment.all
  end

  # GET /attachments/1 or /attachments/1.json
  def show
  end

  # GET /attachments/new
  def new
    @attachment = Attachment.new
  end

  # GET /attachments/1/edit
  def edit
  end

  # POST /attachments or /attachments.json
  def create
    @attachment = Attachment.new(attachment_params)

    respond_to do |format|
      if @attachment.save
        format.html { redirect_to attachment_url(@attachment), notice: "Attachment was successfully created." }
        format.js 
      else
        format.html { render :new, status: :unprocessable_entity }
        format.js 
      end
    end
  end

  # PATCH/PUT /attachments/1 or /attachments/1.json
  def update
    respond_to do |format|
      if @attachment.update(attachment_params)
        format.html { redirect_back(fallback_location: root_path) }
        format.json { respond_with_bip(@attachment) }
      else
        format.html { redirect_back(fallback_location: root_path) }
        format.json { respond_with_bip(@attachment) }
      end
    end
  end

  # DELETE /attachments/1 or /attachments/1.json
  def destroy
    @attachment.destroy

    respond_to do |format|
      format.html { redirect_to attachments_url, notice: "Attachment was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_attachment
      @attachment = Attachment.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def attachment_params
      params.require(:attachment).permit(:description, :attached, :plan_id)
    end
end
