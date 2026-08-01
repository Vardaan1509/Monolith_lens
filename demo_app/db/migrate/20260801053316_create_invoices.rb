class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.integer :user_id
      t.integer :amount_cents
      t.string :status

      t.timestamps
    end
  end
end
