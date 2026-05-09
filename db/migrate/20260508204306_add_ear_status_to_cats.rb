class AddEarStatusToCats < ActiveRecord::Migration[8.1]
  def change
    add_column :cats, :ear_status, :string
  end
end
