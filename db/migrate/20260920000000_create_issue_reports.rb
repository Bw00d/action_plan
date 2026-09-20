class CreateIssueReports < ActiveRecord::Migration[6.0]
  def change
    create_table :issue_reports do |t|
      t.string  :kind,        null: false, default: 'bug'   # bug / question / feature
      t.string  :title,       null: false
      t.text    :description, null: false
      t.string  :page_url                                    # captured automatically
      t.bigint  :user_id                                     # nullable — pages may allow anon
      t.bigint  :incident_id                                 # nullable — non-incident pages
      t.string  :status, default: 'open'
      t.timestamps
    end
    add_index :issue_reports, :user_id
    add_index :issue_reports, :incident_id
    add_index :issue_reports, :kind
  end
end
