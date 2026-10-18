class AirOpsUasEntriesController < ApplicationController
  include SkipAuthorization

  def create
    ao = find_or_create_air_operation
    next_pos = (ao.uas_entries.maximum(:position) || 0) + 1
    ao.uas_entries.create!(position: next_pos)
    redirect_back fallback_location: root_path
  end

  def update
    row = AirOpsUasEntry.find(params[:id])
    respond_to do |format|
      format.json do
        row.update(row_params)
        respond_with_bip(row)
      end
    end
  end

  def destroy
    AirOpsUasEntry.find(params[:id]).destroy
    redirect_back fallback_location: root_path
  end

  private

  def find_or_create_air_operation
    plan = Plan.find(params[:plan_id])
    plan.air_operation || plan.create_air_operation!
  end

  def row_params
    params.require(:air_ops_uas_entry).permit(:identifier, :cat_type,
                                              :make_model, :location,
                                              :start_time, :available,
                                              :leader_contact, :remarks)
  end
end
