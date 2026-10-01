class AddJobTrackingToIsuiteImportStagings < ActiveRecord::Migration[6.0]
  # Extends the staging table so a background IsuiteImportJob can write
  # its progress back and the UI can poll for completion. All columns
  # nullable / default-safe so pre-existing staging rows stay valid
  # until their TTL sweeps them away.
  def change
    change_table :isuite_import_stagings do |t|
      # pending=0 (not yet enqueued), queued=1 (job enqueued), running=2,
      # succeeded=3, failed=4. Enum lives on the model.
      t.integer :status, null: false, default: 0

      # JSON-serialized arrays of IDs the operator ticked on the preview
      # page. Nullable because they're set at enqueue time, not at
      # upload time.
      t.text :selected_resource_ids
      t.text :selected_roster_ids

      # Serialized IsuiteImporter::Result hash so the UI can render the
      # same success summary the old inline flow produced.
      t.text :result

      # Last error if the job raised. Keeps the UI from having to crawl
      # Heroku logs for a diagnosis.
      t.text :error_message

      t.datetime :started_at
      t.datetime :finished_at

      # ActiveJob provider_job_id — handy for correlating with GoodJob's
      # own tables when debugging.
      t.string :job_id
    end

    add_index :isuite_import_stagings, :status
  end
end
