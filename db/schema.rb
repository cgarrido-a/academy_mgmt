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

ActiveRecord::Schema[7.1].define(version: 2025_11_11_132627) do
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

  create_table "enrollments", force: :cascade do |t|
    t.integer "student_id", null: false
    t.integer "payment_plan_id", null: false
    t.integer "section_id", null: false
    t.integer "payment_method_id", null: false
    t.integer "enrollment_amount"
    t.date "payment_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_method_id"], name: "index_enrollments_on_payment_method_id"
    t.index ["payment_plan_id"], name: "index_enrollments_on_payment_plan_id"
    t.index ["section_id"], name: "index_enrollments_on_section_id"
    t.index ["student_id"], name: "index_enrollments_on_student_id"
  end

  create_table "installments", force: :cascade do |t|
    t.integer "tuition_fee_id", null: false
    t.date "due_date"
    t.integer "amount"
    t.date "payment_date"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tuition_fee_id"], name: "index_installments_on_tuition_fee_id"
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
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "schedule", default: "[]"
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

  create_table "tuition_fees", force: :cascade do |t|
    t.integer "enrollment_id", null: false
    t.integer "payment_method_id", null: false
    t.string "billing_period"
    t.integer "total_tuition_fee"
    t.integer "instalments_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_id"], name: "index_tuition_fees_on_enrollment_id"
    t.index ["payment_method_id"], name: "index_tuition_fees_on_payment_method_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "admin_users", "users"
  add_foreign_key "enrollments", "payment_methods"
  add_foreign_key "enrollments", "payment_plans"
  add_foreign_key "enrollments", "sections"
  add_foreign_key "enrollments", "students"
  add_foreign_key "installments", "tuition_fees"
  add_foreign_key "salary_payments", "payment_methods"
  add_foreign_key "salary_payments", "teachers"
  add_foreign_key "sections", "courses"
  add_foreign_key "sections", "teachers"
  add_foreign_key "students", "users"
  add_foreign_key "teachers", "users"
  add_foreign_key "tuition_fees", "enrollments"
  add_foreign_key "tuition_fees", "payment_methods"
end
