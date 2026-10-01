require 'json'

# Short-lived cache of an uploaded e-iSuite CSV between the preview and
# apply steps of the import flow. Backed by Postgres so it survives dyno
# restarts and works across multiple web processes (Rails.cache with the
# default file/memory store does neither reliably on Heroku).
#
# Now doubles as the handoff + progress record for the background
# IsuiteImportJob: the preview-page submission stashes the operator's
# selections here, the job updates status/result as it runs, and the
# progress page polls #status / #result for completion.
class IsuiteImportStaging < ApplicationRecord
  belongs_to :incident
  belongs_to :user, optional: true

  TTL = 30.minutes

  enum status: {
    pending:   0,  # staged, no job yet (upload → preview window)
    queued:    1,  # job enqueued, worker hasn't picked it up
    running:   2,  # worker is applying rows
    succeeded: 3,
    failed:    4
  }

  def self.stash(incident:, user:, csv_data:)
    create!(
      token:      SecureRandom.hex(16),
      incident:   incident,
      user:       user,
      csv_data:   csv_data,
      expires_at: TTL.from_now
    )
  end

  def self.find_active(token)
    where("expires_at > ?", Time.current).find_by(token: token)
  end

  def self.sweep_expired!
    where("expires_at <= ?", Time.current).delete_all
  end

  # Called by the controller right before enqueueing the job — persists
  # the operator's checkbox selections so the worker can pick them up
  # without a hot handoff.
  def record_selections!(resource_ids:, roster_ids:)
    update!(
      selected_resource_ids: JSON.dump(Array(resource_ids).map(&:to_s)),
      selected_roster_ids:   JSON.dump(Array(roster_ids).map(&:to_s)),
      status:                :queued
    )
  end

  def selected_resource_ids_array
    selected_resource_ids.present? ? JSON.parse(selected_resource_ids) : []
  end

  def selected_roster_ids_array
    selected_roster_ids.present? ? JSON.parse(selected_roster_ids) : []
  end

  # Serialize an IsuiteImporter::Result into the record. Struct members
  # become hash keys so we can rehydrate for the status page.
  def record_result!(result)
    update!(
      status:       :succeeded,
      finished_at:  Time.current,
      result:       JSON.dump(result.to_h),
      error_message: nil
    )
  end

  def record_failure!(exception)
    update!(
      status:        :failed,
      finished_at:   Time.current,
      error_message: "#{exception.class}: #{exception.message}"
    )
  end

  def result_hash
    return {} if result.blank?
    JSON.parse(result).with_indifferent_access
  end

  # True once the job's reached a terminal state — the progress page
  # stops polling when this flips.
  def done?
    succeeded? || failed?
  end
end
