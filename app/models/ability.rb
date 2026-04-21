class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)

    if user.admin_user.present?
      # Admins can do everything
      can :manage, :all
    elsif user.teacher.present?
      teacher = user.teacher

      # Teachers can access dashboard (read only)
      can :read, :dashboard
      can :index, :dashboard

      # Teachers can only read courses where they have sections assigned
      can :read, Course, sections: { teacher_id: teacher.id }
      can :attendance, Course, sections: { teacher_id: teacher.id }

      # Teachers can only read their own sections
      can :read, Section, teacher_id: teacher.id

      # Teachers can take attendance on their own sections
      can :take_attendance, Section, teacher_id: teacher.id

      # Teachers can read students enrolled in their sections
      can :read, Student, enrollments: { sections: { teacher_id: teacher.id } }
      can :read, Enrollment, sections: { teacher_id: teacher.id }
      can :read, EnrollmentSection, section: { teacher_id: teacher.id }
      can :update, EnrollmentSection, section: { teacher_id: teacher.id }
    elsif user.student.present?
      # Students have no admin panel access
      cannot :manage, :all
    else
      # Guest users (not logged in)
      cannot :manage, :all
    end
  end
end
