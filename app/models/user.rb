class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # :registerable removed - only admins can create users
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_one :student, dependent: :destroy
  has_one :teacher, dependent: :destroy
  has_one :admin_user, dependent: :destroy

  # Validations
  validates :name, presence: true
  # Datos de contacto del apoderado: opcionales, pero si vienen deben ser válidos.
  validates :guardian_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: 'no tiene un formato válido' },
                             allow_blank: true

  def guardian_contact?
    guardian_email.present? || guardian_phone.present?
  end

  # Correos de los admins para avisos internos (copias de confirmaciones, alertas).
  #
  # Filtra vacíos, inválidos y de prueba (@example.com y compañía) porque Resend
  # rechaza el mensaje COMPLETO (550) si un solo destinatario es inválido: un
  # admin@example.com en la base dejaba sin correo también a la alumna.
  def self.admin_notification_emails
    joins(:admin_user).distinct.pluck(:email).compact.select do |email|
      email.present? && email.match?(URI::MailTo::EMAIL_REGEXP) &&
        !email.match?(/@(example\.(com|org|net)|test\.|localhost)/i)
    end
  end
end
