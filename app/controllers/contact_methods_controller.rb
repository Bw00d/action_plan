# Phone numbers and emails on the signed-in user's profile. Always scoped
# to current_user, so one user can't reach another's.
class ContactMethodsController < ApplicationController
  before_action :set_contact_method, only: %i[update destroy]

  # POST /profile/contact_methods
  def create
    @contact_method = current_user.contact_methods.build(contact_method_params)
    @contact_method.position = current_user.contact_methods.maximum(:position).to_i + 1
    authorize @contact_method
    if @contact_method.save
      redirect_to edit_profile_path(anchor: 'contacts'), notice: 'Contact added.'
    else
      redirect_to edit_profile_path(anchor: 'contacts'),
                  alert: "Couldn't add contact: #{@contact_method.errors.full_messages.to_sentence}"
    end
  end

  # PATCH /profile/contact_methods/:id
  def update
    if @contact_method.update(contact_method_params)
      redirect_to edit_profile_path(anchor: 'contacts'),
                  notice: @contact_method.shared? ? 'Shown on your profile.' : 'Hidden from your profile.'
    else
      redirect_to edit_profile_path(anchor: 'contacts'),
                  alert: @contact_method.errors.full_messages.to_sentence
    end
  end

  # DELETE /profile/contact_methods/:id
  def destroy
    @contact_method.destroy
    redirect_to edit_profile_path(anchor: 'contacts'), notice: 'Contact removed.'
  end

  private

  def set_contact_method
    @contact_method = current_user.contact_methods.find(params[:id])
    authorize @contact_method
  end

  def contact_method_params
    params.require(:contact_method).permit(:kind, :label, :value, :shared)
  end
end
