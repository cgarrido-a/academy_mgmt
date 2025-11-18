module Admin
  class TransbankTransactionsController < Admin::ApplicationController
    before_action :set_transaction, only: [:show]

    def index
      @transactions = TransbankTransaction.includes(:enrollment, :tuition_fee, enrollment: { student: :user })

      # Apply status filter if provided
      if params[:status].present? && ['authorized', 'pending', 'failed', 'nullified'].include?(params[:status])
        @transactions = @transactions.where(status: params[:status])
      end

      @transactions = @transactions.order(created_at: :desc).page(params[:page]).per(50)

      # Stats (always show total stats, not filtered)
      @total_transactions = TransbankTransaction.count
      @authorized_count = TransbankTransaction.authorized.count
      @pending_count = TransbankTransaction.pending.count
      @failed_count = TransbankTransaction.failed.count
      @total_amount_authorized = TransbankTransaction.authorized.sum(:amount)
    end

    def show
      @payment = @transaction.enrollment.payments.find_by(reference_number: @transaction.authorization_code) if @transaction.authorized?
    end

    private

    def set_transaction
      @transaction = TransbankTransaction.includes(:enrollment, :tuition_fee, enrollment: { student: :user }).find(params[:id])
    end
  end
end
