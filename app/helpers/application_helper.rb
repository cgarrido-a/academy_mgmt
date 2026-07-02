module ApplicationHelper
  # Definición de los roles asignables a un usuario. El orden aquí es el orden
  # en que se muestran los checkboxes y los badges.
  USER_ROLES = [
    { key: 'teacher', label: '👨‍🏫 Profesor',    color: '#3498db' },
    { key: 'student', label: '🎓 Estudiante',    color: '#27ae60' },
    { key: 'admin',   label: '⚙️ Administrador', color: '#e74c3c' }
  ].freeze

  # Roles actualmente asignados a un usuario, como array de claves
  # ('teacher', 'student', 'admin'). Un usuario puede tener varios.
  def assigned_role_keys(user)
    keys = []
    keys << 'teacher' if user.teacher
    keys << 'student' if user.student
    keys << 'admin'   if user.admin_user
    keys
  end

  # Badge de color para un rol dado.
  def role_badge(role_key)
    role = USER_ROLES.find { |r| r[:key] == role_key }
    return unless role

    content_tag :span, role[:label],
                style: "background: #{role[:color]}; color: white; padding: 0.25rem 0.5rem; " \
                       "border-radius: 4px; display: inline-block; margin: 0 0.2rem 0.2rem 0;"
  end
end
