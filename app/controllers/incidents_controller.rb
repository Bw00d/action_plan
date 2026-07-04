class IncidentsController < ApplicationController
  before_action :set_incident, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  # skip_before_action :authenticate_user!

  
  def users
    @incident = Incident.find(params[:id])
    @users = @incident.users
  end
  # GET /incidents
  # GET /incidents.json
  def index
    # Owner (user_id) + shared collaborators (incidents_users join table),
    # deduped so an owner who is also in the join table isn't listed twice.
    owned  = Incident.where(user_id: current_user.id)
    shared = Incident.joins(:users).where(users: { id: current_user.id })
    @incidents = Incident.where(id: (owned.pluck(:id) + shared.pluck(:id)).uniq)
  end

  # GET /incidents/1
  # GET /incidents/1.json
  def show
    @resources = @incident.resources.order(:category, :order_number)
    @resource = Resource.new
  end

  # GET /incidents/new
  def new
    @incident = Incident.new
  end

  # GET /incidents/1/edit
  def edit
  end

  # POST /incidents
  # POST /incidents.json
  def create
    @incident = Incident.new(incident_params)

    respond_to do |format|
      if @incident.save
        @incident.users << current_user
        Incidents::SeedOrgChart.call(@incident)
        format.html { redirect_to incident_path(@incident) }
        format.js { }
        format.json { render incident_path(@incident), status: :created, location: @incident }
      else
        format.html { render :new }
        format.json { render json: @incident.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /incidents/1
  # PATCH/PUT /incidents/1.json
  def update
    respond_to do |format|
      if @incident.update(incident_params)
        format.html { redirect_to incident_plans_path(@incident) }
        format.json { render :show, status: :ok, location: @incident }
      else
        format.html { redirect_to incident_plans_path(@incident) }
        format.json { render json: @incident.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /incidents/1
  # DELETE /incidents/1.json
  def destroy
    @incident.destroy
    respond_to do |format|
      format.html { redirect_to incidents_url, notice: 'Incident was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def invite
    @incident = Incident.find(params[:incident_id])
    email = params[:invite].to_s.strip.downcase

    if email.blank?
      redirect_back(fallback_location: incident_users_path(@incident), alert: "Please enter an email address.")
      return
    end

    existing = User.find_by(email: email)

    if existing
      if @incident.users.exists?(existing.id)
        notice = "#{existing.email} is already a collaborator on this incident."
      else
        @incident.users << existing
        InvitationMailer.added_to_incident(existing, @incident, current_user).deliver_later
        notice = "Added #{existing.email} and sent them a notification."
      end
      redirect_to incident_users_path(@incident), notice: notice
    else
      # Fresh invite: create a placeholder user with a random password so
      # Devise's :validatable is satisfied, generate a raw invitation token
      # (piggybacks on Devise's confirmation_token infrastructure), and send
      # the accept-invitation email.
      raw_token, digest = Devise.token_generator.generate(User, :confirmation_token)
      new_user = User.new(
        email:                 email,
        first_name:            "Pending",
        last_name:             "Invitee",
        password:              SecureRandom.hex(16) + "Aa1", # meets password_strength rules
        password_confirmation: nil
      )
      new_user.password_confirmation = new_user.password
      new_user.skip_confirmation_notification! if new_user.respond_to?(:skip_confirmation_notification!)
      new_user.confirmation_token   = digest
      new_user.confirmation_sent_at = Time.current
      if new_user.save
        @incident.users << new_user
        InvitationMailer.invite_new_user(new_user, @incident, current_user, raw_token).deliver_later
        redirect_to incident_users_path(@incident), notice: "Invitation sent to #{email}."
      else
        redirect_to incident_users_path(@incident), alert: "Couldn't invite #{email}: #{new_user.errors.full_messages.to_sentence}"
      end
    end
  end

  def remove_user
    @incident = Incident.find(params[:incident_id])
    @user = User.find(params[:user]) 
    @incident.users.delete(@user)
    respond_to do |format|
      format.html { redirect_back(fallback_location: "#{@incident.id}/users") }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_incident
      @incident = Incident.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def incident_params
      params.require(:incident).permit(:name, :number, :p_code, :user_id, :financial_code, :size,
                                       :incident_type, :complexity, :status, :cause, :fuel_type, 
                                       :start_date, :containment_date, :control_date, :out_date, 
                                       :percent_contained, :location, :ownership, :protection,
                                       :latitude, :longitude, :ic, :fire_behavior )
    end
end