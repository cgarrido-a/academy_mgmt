class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)

    if user.admin_user.present?
      # Admins can do everything
      can :manage, :all
    elsif user.teacher.present?
      # Teachers can access dashboard (read only)
      can :read, :dashboard
      can :index, :dashboard

      # Teachers can view and manage courses
      can :read, Course
      can :manage, Course

      # Teachers can manage sections (all sections, not just theirs)
      # You can restrict this later if needed: can :manage, Section, teacher_id: user.teacher.id
      can :manage, Section

      # Teachers cannot access financial/admin features
      cannot :manage, Enrollment
      cannot :manage, Payment
      cannot :manage, TransbankTransaction
      cannot :manage, PaymentMethod
      cannot :manage, PaymentPeriod
      cannot :manage, WeeklyPlan
      cannot :manage, User
      cannot :manage, EnrollmentSection
    elsif user.student.present?
      # Students have no admin panel access
      cannot :manage, :all
    else
      # Guest users (not logged in)
      cannot :manage, :all
    end
  end
end
