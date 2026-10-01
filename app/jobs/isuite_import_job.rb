require 'stringio'

# Background apply step of the iSuite import flow. Reads the stashed CSV
# + the operator's selections from an IsuiteImportStaging row, runs
# IsuiteImporter.apply, and writes status/result back to the same row so
# the progress page can poll for completion.
#
# Why a job: large imports easily exceed Heroku's 30-second router
# timeout (H12). Running inline leaves the user with a generic error
# page while writes continue on the dyno until it gets SIGTERMed mid-
# flight. Here the controller returns immediately and the worker owns
# the long call.
class IsuiteImportJob < ApplicationJob
  queue_as :default

  # Keep retries off — a partial failure mid-import leaves half the rows
  # applied; re-running the whole thing would double-apply the first
  # half. If a job fails, the operator reruns the import by hand with
  # the remaining stragglers.
  def perform(staging_id)
    staging = IsuiteImportStaging.find_by(id: staging_id)
    return unless staging  # expired or deleted

    staging.update!(status: :running, started_at: Time.current)

    rows = IsuiteImporter.new(StringIO.new(staging.csv_data)).parsed_rows

    result = IsuiteImporter.apply(
      staging.incident,
      rows,
      selected_resource_ids: staging.selected_resource_ids_array,
      selected_roster_ids:   staging.selected_roster_ids_array
    )

    staging.record_result!(result)
  rescue => e
    Rails.logger.error "IsuiteImportJob##{staging_id} failed: #{e.class}: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    staging&.record_failure!(e)
    raise  # let GoodJob record the failure in its own tables too
  end
end
