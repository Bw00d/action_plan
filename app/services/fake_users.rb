# Finds bot sign-ups whose names are random letter strings, like
# "rKAvJkWinKseuJUa aUJDxOrPrxbDTdHH", and deletes the ones that never
# touched anything. Used by `rails users:purge_fake`.
module FakeUsers
  # Every column that points at a user. A match with any of these is
  # left alone for a person to review, since deleting a User destroys its
  # owned incidents and plans.
  REFERENCES = [
    %w[incidents user_id],
    %w[incidents_users user_id],
    %w[plans user_id],
    %w[incident_posts user_id],
    %w[incident_post_likes user_id],
    %w[incident_events user_id],
    %w[incident_feed_visits user_id],
    %w[resource_events user_id],
    %w[schedules user_id],
    %w[issue_reports user_id],
    %w[issue_report_comments user_id],
    %w[issue_report_upvotes user_id],
    %w[isuite_import_stagings user_id],
    %w[access_requests reviewed_by_id],
    %w[resources user_id],
    %w[qualifications user_id],
    %w[contact_methods user_id]
  ].freeze

  module_function

  # Letters only, at least 10 long, with 3+ capitals after the first
  # letter. Real names rarely have more than one inner capital
  # ("McDonald"), and almost never in a name this long.
  def random_part?(part)
    part = part.to_s
    part.match?(/\A[A-Za-z]{10,}\z/) && part[1..].count('A-Z') >= 3
  end

  # Both names must look random, so one odd surname never trips it.
  def random_name?(user)
    random_part?(user.first_name) && random_part?(user.last_name)
  end

  def candidates
    User.where.not(role: :admin).select { |u| random_name?(u) }
  end

  # Names of the tables that reference this user; empty means it's safe
  # to delete.
  def references(user)
    conn = User.connection
    REFERENCES.filter_map do |table, column|
      next unless conn.table_exists?(table)
      table if conn.select_value(
        "SELECT 1 FROM #{conn.quote_table_name(table)} WHERE #{conn.quote_column_name(column)} = #{user.id.to_i} LIMIT 1"
      )
    end
  end
end
