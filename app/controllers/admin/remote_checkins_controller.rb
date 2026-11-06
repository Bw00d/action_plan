# Admin review queue for the public remote-checkin form. This is NOT
# where resources are created — the Check In button on each row routes
# through the normal RequestCheckinsController flow with the submission
# pre-filled, so every normal validation and sidecar event still fires.
module Admin
  class RemoteCheckinsController < ApplicationController
    include SkipAuthorization
    before_action :authenticate_user!
    before_action :set_incident
    before_action :authorize_access
    before_action :set_remote_checkin, only: [:dismiss, :rematch, :destroy]

    def index
      @pending   = @incident.remote_checkins.pending.submitted.pending_first
      @promoted  = @incident.remote_checkins.promoted.order(promoted_at: :desc).limit(25)
      @dismissed = @incident.remote_checkins.dismissed.submitted.order(updated_at: :desc).limit(25)
      @public_url = remote_checkin_url(@incident.remote_checkin_token, **public_link_options)
    end

    # Mark a submission as reviewed-but-not-wanted (e.g. duplicate,
    # resource wandered off, test submission). Stays on the list under
    # "Dismissed" so it can be undone or audited.
    def dismiss
      @remote_checkin.update!(status: :dismissed)
      redirect_to incident_remote_checkins_path(@incident),
                  notice: "Dismissed submission from #{@remote_checkin.name.presence || 'unknown resource'}."
    end

    # Look an unmatched submission's request number up again — e.g. after
    # an IROC import brought the request in. On a match the row gets the
    # normal Check In button.
    def rematch
      if (req = @remote_checkin.rematch!)
        redirect_to incident_remote_checkins_path(@incident),
                    notice: "Matched #{@remote_checkin.name.presence || 'submission'} to #{req.req_number}."
      else
        redirect_to incident_remote_checkins_path(@incident),
                    alert: "Still no request #{@remote_checkin.req_number_raw.presence || '(blank)'} on this incident. " \
                           'Use Check in anyway to fix the number on the check-in form.'
      end
    end

    def destroy
      @remote_checkin.destroy!
      redirect_to incident_remote_checkins_path(@incident), notice: 'Submission deleted.'
    end

    # Rotate the public URL token. Resources using the old link will
    # see "This check-in link is invalid or has been rotated." and
    # must be given the new one by the Plans section.
    def rotate_token
      @incident.rotate_remote_checkin_token!
      redirect_to incident_remote_checkins_path(@incident),
                  notice: 'Public check-in link rotated. Share the new URL below with arriving resources.'
    end

    # PNG QR code of the current public check-in link, to print or post.
    def qr_code
      send_data LinkQrCode.png(remote_checkin_url(@incident.remote_checkin_token, **public_link_options)),
                type: 'image/png', disposition: 'attachment',
                filename: "#{@incident.name.to_s.parameterize.presence || 'incident'}-check-in-qr.png"
    end

    private

    def set_incident
      @incident = Incident.find(params[:incident_id])
    end

    # The queue is a planning-section tool; anyone signed into the
    # incident can see arriving check-ins. If you want to tighten
    # this to admins only, change the predicate here.
    def authorize_access
      head :forbidden unless current_user.present?
    end

    def set_remote_checkin
      @remote_checkin = @incident.remote_checkins.find(params[:id])
    end
  end
end
