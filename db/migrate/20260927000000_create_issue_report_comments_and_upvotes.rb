class CreateIssueReportCommentsAndUpvotes < ActiveRecord::Migration[6.0]
  def change
    create_table :issue_report_comments do |t|
      t.bigint :issue_report_id, null: false
      t.bigint :user_id,         null: false
      t.text   :body,            null: false
      t.timestamps
    end
    add_index :issue_report_comments, :issue_report_id
    add_index :issue_report_comments, :user_id

    create_table :issue_report_upvotes do |t|
      t.bigint :issue_report_id, null: false
      t.bigint :user_id,         null: false
      t.timestamps
    end
    add_index :issue_report_upvotes, [:issue_report_id, :user_id],
              unique: true, name: 'idx_issue_report_upvotes_unique'
    add_index :issue_report_upvotes, :user_id
  end
end
