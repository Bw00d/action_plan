module Admin
  # Admins add certified qualifications, certify self-reported ones, and
  # correct or remove any of them.
  class QualificationsController < ApplicationController
    before_action :set_user
    before_action :set_qualification, only: %i[update destroy]

    # GET /admin/users/:user_id/qualifications
    def index
      @qualifications = policy_scope(@user.qualifications).includes(:position, :certified_by).display_order
      @positions = Position.alphabetical.where.not(id: @user.qualifications.select(:position_id))
      @qualification = Qualification.new
    end

    # POST /admin/users/:user_id/qualifications
    def create
      @qualification = @user.qualifications.build(params.require(:qualification).permit(:position_id, :status))
      @qualification.assign_attributes(source: :certified, certified_by: current_user, certified_at: Time.current)
      authorize @qualification
      if @qualification.save
        redirect_to admin_user_qualifications_path(@user), notice: "Added #{@qualification.position.code} as certified."
      else
        redirect_to admin_user_qualifications_path(@user),
                    alert: "Couldn't add qualification: #{@qualification.errors.full_messages.to_sentence}"
      end
    end

    # PATCH /admin/users/:user_id/qualifications/:id
    # status change, or source: certified to certify a self-reported qual.
    def update
      attrs = params.require(:qualification).permit(:status, :source)
      @qualification.assign_attributes(attrs)
      if @qualification.source_changed?(to: 'certified')
        @qualification.assign_attributes(certified_by: current_user, certified_at: Time.current)
      elsif @qualification.source_changed?(to: 'self_reported')
        @qualification.assign_attributes(certified_by: nil, certified_at: nil)
      end
      # Re-check with the changes applied, so certifying is admin-only.
      authorize @qualification
      @qualification.save!
      redirect_to admin_user_qualifications_path(@user), notice: "Updated #{@qualification.position.code}."
    end

    # DELETE /admin/users/:user_id/qualifications/:id
    def destroy
      @qualification.destroy
      redirect_to admin_user_qualifications_path(@user), notice: "Removed #{@qualification.position.code}."
    end

    private

    # The whole controller is admin-only; the per-record checks in
    # QualificationPolicy are a second layer.
    def set_user
      @user = User.friendly.find(params[:user_id])
      authorize @user, :manage_qualifications?, policy_class: ProfilePolicy
    end

    def set_qualification
      @qualification = @user.qualifications.find(params[:id])
      authorize @qualification
    end
  end
end
