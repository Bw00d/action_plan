# The signed-in user's qualifications, always scoped to current_user.
class QualificationsController < ApplicationController
  before_action :set_qualification, only: %i[update destroy]

  # POST /profile/qualifications
  def create
    @qualification = current_user.qualifications.build(qualification_params)
    authorize @qualification
    if @qualification.save
      redirect_to edit_profile_path(anchor: 'qualifications'), notice: 'Qualification added.'
    else
      redirect_to edit_profile_path(anchor: 'qualifications'),
                  alert: "Couldn't add qualification: #{@qualification.errors.full_messages.to_sentence}"
    end
  end

  # PATCH /profile/qualifications/:id
  def update
    @qualification.update(params.require(:qualification).permit(:status))
    redirect_to edit_profile_path(anchor: 'qualifications'), notice: 'Qualification updated.'
  end

  # DELETE /profile/qualifications/:id
  def destroy
    @qualification.destroy
    redirect_to edit_profile_path(anchor: 'qualifications'), notice: 'Qualification removed.'
  end

  private

  def set_qualification
    @qualification = current_user.qualifications.find(params[:id])
    authorize @qualification
  end

  def qualification_params
    params.require(:qualification).permit(:position_id, :status)
  end
end
