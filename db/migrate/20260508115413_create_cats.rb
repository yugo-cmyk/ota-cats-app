class CreateCats < ActiveRecord::Migration[8.1]
  def change
    create_table :cats do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
