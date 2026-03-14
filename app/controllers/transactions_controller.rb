class TransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account

  def new
    @transaction = Transaction.new
  end

  def create
    @transaction = @account.transactions.build(transaction_params)
    if @transaction.save
      redirect_to @account, notice: "Transacción registrada exitosamente."
    else
      @transactions = @account.transactions.order(transaction_date: :desc, created_at: :desc)
      @new_transaction = @transaction
      render "accounts/show", status: :unprocessable_entity
    end
  end

  def destroy
    @transaction = @account.transactions.find(params[:id])
    @transaction.destroy
    redirect_to @account, notice: "Transacción eliminada exitosamente.", status: :see_other
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:account_id])
  rescue Mongoid::Errors::DocumentNotFound
    flash[:alert] = "No tienes acceso a esta cuenta."
    redirect_to accounts_path
  end

  def transaction_params
    params.require(:transaction).permit(:amount, :transaction_type, :description, :transaction_date)
  end
end