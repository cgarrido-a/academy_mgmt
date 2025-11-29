# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_11_29_222142) do
  create_table "admin_users", force: :cascade do |t|
    t.string "admin_type"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_admin_users_on_user_id"
  end

  create_table "courses", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "enrollment_sections", force: :cascade do |t|
    t.integer "enrollment_id", null: false
    t.integer "section_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "date"
    t.index ["enrollment_id", "section_id", "date"], name: "index_enrollment_sections_on_enrollment_section_and_date", unique: true
    t.index ["enrollment_id"], name: "index_enrollment_sections_on_enrollment_id"
    t.index ["section_id"], name: "index_enrollment_sections_on_section_id"
  end

  create_table "enrollments", force: :cascade do |t|
    t.integer "student_id", null: false
    t.integer "payment_plan_id", null: false
    t.integer "payment_method_id", null: false
    t.integer "enrollment_amount"
    t.date "payment_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "total_tuition_fee"
    t.index ["payment_method_id"], name: "index_enrollments_on_payment_method_id"
    t.index ["payment_plan_id"], name: "index_enrollments_on_payment_plan_id"
    t.index ["student_id"], name: "index_enrollments_on_student_id"
  end

  create_table "payment_methods", force: :cascade do |t|
    t.string "payment_method"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payment_plans", force: :cascade do |t|
    t.string "plan"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "number_of_classes"
    t.integer "price"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "enrollment_id", null: false
    t.string "payment_type", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.date "payment_date", null: false
    t.integer "payment_method_id", null: false
    t.string "reference_number"
    t.text "notes"
    t.integer "processed_by_id"
    t.string "status", default: "completed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_id", "payment_type"], name: "index_payments_on_enrollment_id_and_payment_type"
    t.index ["enrollment_id"], name: "index_payments_on_enrollment_id"
    t.index ["payment_date"], name: "index_payments_on_payment_date"
    t.index ["payment_method_id"], name: "index_payments_on_payment_method_id"
    t.index ["processed_by_id"], name: "index_payments_on_processed_by_id"
  end

  create_table "salary_payments", force: :cascade do |t|
    t.integer "teacher_id", null: false
    t.integer "payment_method_id", null: false
    t.integer "amount"
    t.string "status"
    t.date "payment_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_method_id"], name: "index_salary_payments_on_payment_method_id"
    t.index ["teacher_id"], name: "index_salary_payments_on_teacher_id"
  end

  create_table "sections", force: :cascade do |t|
    t.integer "course_id", null: false
    t.integer "teacher_id", null: false
    t.integer "places"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "schedule", default: "[]"
    t.string "weekday"
    t.index ["course_id"], name: "index_sections_on_course_id"
    t.index ["teacher_id"], name: "index_sections_on_teacher_id"
  end

  create_table "students", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_students_on_user_id"
  end

  create_table "teachers", force: :cascade do |t|
    t.string "profession"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_teachers_on_user_id"
  end

  create_table "transbank_transactions", force: :cascade do |t|
    t.integer "enrollment_id", null: false
    t.string "payment_type", null: false
    t.string "token", null: false
    t.string "buy_order", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "status", default: "pending", null: false
    t.string "authorization_code"
    t.string "payment_type_code"
    t.integer "response_code"
    t.string "card_number"
    t.datetime "transaction_date"
    t.text "raw_response"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["buy_order"], name: "index_transbank_transactions_on_buy_order"
    t.index ["enrollment_id"], name: "index_transbank_transactions_on_enrollment_id"
    t.index ["status"], name: "index_transbank_transactions_on_status"
    t.index ["token"], name: "index_transbank_transactions_on_token", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone"
  end

  add_foreign_key "admin_users", "users"
  add_foreign_key "enrollment_sections", "enrollments"
  add_foreign_key "enrollment_sections", "sections"
  add_foreign_key "enrollments", "payment_methods"
  add_foreign_key "enrollments", "payment_plans"
  add_foreign_key "enrollments", "students"
  add_foreign_key "payments", "enrollments"
  add_foreign_key "payments", "payment_methods"
  add_foreign_key "payments", "users", column: "processed_by_id"
  add_foreign_key "salary_payments", "payment_methods"
  add_foreign_key "salary_payments", "teachers"
  add_foreign_key "sections", "courses"
  add_foreign_key "sections", "teachers"
  add_foreign_key "students", "users"
  add_foreign_key "teachers", "users"
  add_foreign_key "transbank_transactions", "enrollments"
end
