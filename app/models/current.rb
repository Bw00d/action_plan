# Per-request (and per-job) globals. Reset automatically by the Rails
# executor at the end of every request / job.
class Current < ActiveSupport::CurrentAttributes
  # Who is making this change — set in ApplicationController so model
  # callbacks can attribute live-update notices to a person.
  attribute :user
  # [incident_id, area] pairs already announced during this request/job,
  # so a bulk import sends one notice instead of hundreds.
  attribute :announced_changes
end
