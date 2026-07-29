class CreateClassDiscounts < ActiveRecord::Migration[7.1]
  # Descuento GLOBAL por cantidad total de clases (frecuencia × meses). El descuento
  # de una compra sale del tramo cuyo `number_of_classes` es el mayor <= al total de
  # clases compradas. Reemplaza al modelo "descuento por período" (los meses ya no
  # aportan descuento propio; solo definen cuántas clases se compran).
  def up
    create_table :class_discounts do |t|
      t.integer :number_of_classes, null: false
      t.integer :discount_percentage, null: false, default: 0
      t.timestamps
    end
    add_index :class_discounts, :number_of_classes, unique: true

    # Curva por defecto (editable después desde el admin). 4/8/12/16 reproducen los
    # precios mensuales actuales; 24+ crecen sin dispararse.
    { 4 => 0, 8 => 10, 12 => 15, 16 => 20, 24 => 25, 32 => 28, 48 => 30, 64 => 32 }.each do |nc, d|
      execute "INSERT INTO class_discounts (number_of_classes, discount_percentage, created_at, updated_at) VALUES (#{nc}, #{d}, NOW(), NOW())"
    end
  end

  def down
    drop_table :class_discounts
  end
end
