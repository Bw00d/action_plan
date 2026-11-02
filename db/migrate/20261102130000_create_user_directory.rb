# User directory: profile fields on users, shareable contact methods, a
# catalog of NWCG positions, per-user qualifications, and a link from an
# incident Resource (an assignment) back to the User who filled it.
class CreateUserDirectory < ActiveRecord::Migration[6.0]
  def change
    change_table :users, bulk: true do |t|
      t.string  :home_unit
      t.string  :dispatch_center
      t.integer :availability, null: false, default: 0
      t.date    :available_on
      t.string  :emergency_contact_name
      t.string  :emergency_contact_phone
      t.string  :emergency_contact_relation
    end

    create_table :contact_methods do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :kind, null: false
      t.string  :label
      t.string  :value, null: false
      t.boolean :shared, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :positions do |t|
      t.string :code,  null: false
      t.string :title, null: false
      t.timestamps
    end
    add_index :positions, :code, unique: true

    create_table :qualifications do |t|
      t.references :user,     null: false, foreign_key: { on_delete: :cascade }
      t.references :position, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :source, null: false, default: 0
      t.references :certified_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :certified_at
      t.timestamps
    end
    add_index :qualifications, [:user_id, :position_id], unique: true

    add_reference :resources, :user, foreign_key: { on_delete: :nullify }
  end
end
