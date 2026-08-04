module Admin
  class TransbankTransactionsController < Admin::ApplicationController
    authorize_resource class: TransbankTransaction
    before_action :set_transaction, only: [:show, :reprocess]

    def index
      @transactions = TransbankTransaction.includes(:enrollment, enrollment: { student: :user })

      # Apply status filter if provided
      if params[:status].present? && TransbankTransaction.statuses.key?(params[:status])
        @transactions = @transactions.where(status: params[:status])
      end

      # Sólo las que necesitan mirada humana (cobradas con algo pendiente)
      @transactions = @transactions.needs_review if params[:review] == '1'

      @transactions = @transactions.order(created_at: :desc).page(params[:page]).per(50)

      # Stats (always show total stats, not filtered)
      @total_transactions = TransbankTransaction.count
      @authorized_count = TransbankTransaction.authorized.count
      @pending_count = TransbankTransaction.pending.count
      @failed_count = TransbankTransaction.failed.count
      @needs_review_count = TransbankTransaction.needs_review.count
      @total_amount_authorized = TransbankTransaction.authorized.sum(:amount)
    end

    # POST /admin/transbank_transactions/:id/reprocess
    # Reintenta crear la matrícula de un cobro que Transbank sí capturó.
    def reprocess
      @transaction.reprocess!
      redirect_to admin_transbank_transaction_path(@transaction),
                  notice: "Matrícula creada. La transacción quedó autorizada."
    rescue StandardError => e
      redirect_to admin_transbank_transaction_path(@transaction),
                  alert: "No se pudo reprocesar: #{e.message}"
    end

    def show
      @payment = @transaction.enrollment.payments.find_by(reference_number: @transaction.authorization_code) if @transaction.authorized?
    end

    private

    def set_transaction
      @transaction = TransbankTransaction.includes(:enrollment, enrollment: { student: :user }).find(params[:id])
    end
  end
end
