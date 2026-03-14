class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account, only: [:show, :edit, :update, :destroy]

  def index
    @accounts = current_user.accounts.order(created_at: :desc)
  end

  def show
    @transactions = @account.transactions.order(transaction_date: :desc, created_at: :desc)
    @new_transaction = Transaction.new
  end

  def new
    @account = Account.new
  end

  def create
    @account = Account.new(account_params)
    @account.user = current_user
    if @account.save
      redirect_to @account, notice: "Cuenta creada exitosamente."
    else
      @accounts = current_user.accounts.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to @account, notice: "Cuenta actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @account.destroy
    redirect_to accounts_path, notice: "Cuenta eliminada exitosamente.", status: :see_other
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    flash[:alert] = "No tienes acceso a esta cuenta."
    redirect_to accounts_path
  end

  def account_params
    params.require(:account).permit(:name, :account_type, :bank_name, :account_number, :initial_balance)
  end
end