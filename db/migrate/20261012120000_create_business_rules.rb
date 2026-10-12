class CreateBusinessRules < ActiveRecord::Migration[7.1]
  # Reglas de funcionamiento editables por el admin. Es una tabla de UNA sola fila
  # (BusinessRule.current); 0 en cualquiera de los campos desactiva esa regla.
  def up
    create_table :business_rules do |t|
      # La web pública no deja comprar un plan cuya primera clase sea más de N días
      # después de hoy. El panel admin no tiene este límite.
      t.integer :max_days_ahead_for_start, null: false, default: 30
      # Cupo reservado: una alumna sigue ocupando su lugar en el horario hasta N días
      # después de su última clase, para que pueda renovar sin que se lo quiten.
      t.integer :seat_hold_days, null: false, default: 7
      t.timestamps
    end

    execute "INSERT INTO business_rules (max_days_ahead_for_start, seat_hold_days, created_at, updated_at) VALUES (30, 7, NOW(), NOW())"
  end

  def down
    drop_table :business_rules
  end
end
