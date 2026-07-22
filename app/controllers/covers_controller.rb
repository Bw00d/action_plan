class CoversController < ApplicationController
  before_action :set_cover, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  # skip_before_action :authenticate_user!
  

  # GET /covers
  # GET /covers.json
  def index
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @cover = Cover.new
    respond_to do |format|
      if @plan.cover
        format.html { redirect_to incident_plan_cover_path(@incident, @plan, @plan.cover)}
      else
        format.html { render 'index' }
      end
    end
  end

  # GET /covers/1
  # GET /covers/1.json
  def show
    @cover = Cover.find(params[:id])
    @plan = Plan.find(@cover.plan_id)
    @incident = Incident.find(@plan.incident_id)
    @block = Block.new
    @blocks = @cover.blocks.includes(:main_image_attachment).order(:created_at)
  end

  def cover_to_pdf
    @cover = Cover.find(params[:id])
    @plan = @cover.plan
    @incident = @plan.incident    
    @block = Block.new
    @blocks = @cover.blocks.includes(:main_image_attachment).order(:created_at)

    respond_to do |format|
      format.pdf do
        # Set up for absolute URLs in PDF
        Rails.application.routes.default_url_options[:host] = request.host_with_port
        Rails.application.routes.default_url_options[:protocol] = request.protocol
        
        html = render_to_string(
          template: 'covers/cover_to_pdf.pdf.erb',
          layout: 'layouts/pdf.html.erb',
          locals: { cover: @cover, blocks: @blocks }
        )

        # Single Letter page with zero margins — the cover fills bleed-to-
        # bleed. Kill Chrome's default page header/footer, honor background
        # colors, and let the layout's @page rule win.
        pdf = Grover.new(html,
          display_url:            request.base_url,
          format:                 'Letter',
          margin:                 { top: '0in', right: '0in', bottom: '0in', left: '0in' },
          print_background:       true,
          prefer_css_page_size:   true,
          display_header_footer:  false
        ).to_pdf
        
        send_data pdf, filename: "cover_#{@cover.id}.pdf", type: 'application/pdf', disposition: 'inline'
      end
    end
  end

  # GET /covers/new
  def new
    @cover = Cover.new
  end

  # GET /covers/1/edit
  def edit
  end

  # POST /covers
  # POST /covers.json
  def create
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @cover = Cover.new(cover_params)

    respond_to do |format|
      if @cover.save
        format.html { redirect_to incident_plan_cover_path(@incident, @plan, @cover) }
        format.json { render :show, status: :created, location: @cover }
      else
        format.html { render :new }
        format.json { render json: @cover.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /covers/1
  # PATCH/PUT /covers/1.json
  def update
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    respond_to do |format|
      if @cover.update(cover_params)
        format.html { redirect_to incident_plan_cover_path(@incident, @plan, @cover) }
        format.json { render :show, status: :ok, location: @cover }
      else
        format.html { render :edit }
        format.json { render json: @cover.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /covers/1
  # DELETE /covers/1.json
  def destroy
    # Log where the request came from so we can trace any accidental
    # cover-destroy that the UI shouldn't have triggered.
    Rails.logger.warn "CoversController#destroy called: cover_id=#{@cover.id} referer=#{request.referer.inspect} method=#{request.request_method} params=#{params.to_unsafe_h.except("_method").inspect}"
    @cover.destroy
    respond_to do |format|
      format.html { redirect_to covers_url, notice: 'Cover was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_cover
      @cover = Cover.find(params[:id])
    end

  
    # Only allow a list of trusted parameters through.
    def cover_params
      params.require(:cover).permit(:plan_id)
    end
end
