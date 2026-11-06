# Review queue for the public remote-demob form, linked from the Plans
# page. Applying a submission happens through the DMB button
# (DemobsController), not here.
module Admin
  class RemoteDemobsController < ApplicationController
    include SkipAuthorization
    before_action :authenticate_user!
    before_action :set_incident
    before_action :set_remote_demob, only: [:dismiss, :destroy]

    # Unmatched pending rows are re-matched first — the resource may
    # have been checked in since they submitted.
    def index
      scope = @incident.remote_demobs.submitted.newest_first.includes(:resource, :demob, roster: :resource)
      scope.pending.where(resource_id: nil).each(&:rematch!)
      @pending    = scope.pending.to_a
      @applied    = scope.applied.reorder(applied_at: :desc).limit(25).to_a
      @dismissed  = scope.dismissed.reorder(updated_at: :desc).limit(25).to_a
      @public_url = remote_demob_url(@incident.remote_checkin_token, **public_link_options)
    end

    # Reviewed-but-not-wanted (duplicate, test, wrong incident). Kept
    # under "Dismissed" on the Plans page so it can be audited.
    def dismiss
      @remote_demob.update!(status: :dismissed)
      redirect_to incident_remote_demobs_path(@incident),
                  notice: "Dismissed demob from #{@remote_demob.name.presence || 'unknown resource'}."
    end

    def destroy
      @remote_demob.destroy!
      redirect_to incident_remote_demobs_path(@incident),
                  notice: 'Demob submission deleted.'
    end

    # PNG QR code of the current public demob link, to print or post.
    def qr_code
      send_data LinkQrCode.png(remote_demob_url(@incident.remote_checkin_token, **public_link_options)),
                type: 'image/png', disposition: 'attachment',
                filename: "#{@incident.name.to_s.parameterize.presence || 'incident'}-demob-qr.png"
    end

    private

    def set_incident
      @incident = Incident.find(params[:incident_id])
    end

    def set_remote_demob
      @remote_demob = @incident.remote_demobs.find(params[:id])
    end
  end
end
