class ReplaceOpsPersonnelSlotsWithRolePersonStrings < ActiveRecord::Migration[6.0]
  DEFAULT_ROLES = {
    1 => 'Operations Chief',
    2 => 'Division/Group Supervisor',
    3 => 'Branch Director',
    4 => 'Air Attack Supervisor'
  }.freeze

  OLD_FKS = {
    1 => :operations_chief_id,
    2 => :division_group_supervisor_id,
    3 => :branch_director_id,
    4 => :air_attack_supervisor_id
  }.freeze

  def up
    (1..4).each do |i|
      add_column :assignments, "slot_#{i}_role",   :string, default: DEFAULT_ROLES[i]
      add_column :assignments, "slot_#{i}_person", :string
    end

    # Backfill person names from the existing Team FKs before dropping columns.
    say_with_time "Backfilling slot_N_person from Team associations" do
      execute <<~SQL
        UPDATE assignments a SET
          slot_1_person = t1.resource_name,
          slot_2_person = t2.resource_name,
          slot_3_person = t3.resource_name,
          slot_4_person = t4.resource_name
        FROM assignments a2
        LEFT JOIN teams t1 ON t1.id = a2.operations_chief_id
        LEFT JOIN teams t2 ON t2.id = a2.division_group_supervisor_id
        LEFT JOIN teams t3 ON t3.id = a2.branch_director_id
        LEFT JOIN teams t4 ON t4.id = a2.air_attack_supervisor_id
        WHERE a.id = a2.id;
      SQL
    end

    OLD_FKS.each_value do |col|
      remove_foreign_key :assignments, column: col
      remove_reference   :assignments, col.to_s.sub(/_id\z/, '').to_sym
    end
  end

  def down
    OLD_FKS.each do |_, col|
      ref = col.to_s.sub(/_id\z/, '').to_sym
      add_reference :assignments, ref, foreign_key: { to_table: :teams }, null: true
    end

    (1..4).each do |i|
      remove_column :assignments, "slot_#{i}_role"
      remove_column :assignments, "slot_#{i}_person"
    end
  end
end
