class ThirdPartiesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_third_party, only: [:show, :edit, :update, :destroy]

  def index
    @third_parties = current_user.third_parties.order(created_at: :desc)
  end

  def show
  end

  def new
    @third_party = ThirdParty.new
  end

  def create
    @third_party = ThirdParty.new(third_party_params)
    @third_party.user = current_user
    if @third_party.save
      redirect_to third_parties_path, notice: "Tercero registrado exitosamente."
    else
      @third_parties = current_user.third_parties.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @third_party.update(third_party_params)
      redirect_to third_parties_path, notice: "Tercero actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @third_party.destroy
    redirect_to third_parties_path, notice: "Tercero eliminado exitosamente.", status: :see_other
  end

  private

  def set_third_party
    @third_party = current_user.third_parties.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    flash[:alert] = "No tienes acceso a este tercero."
    redirect_to third_parties_path
  end

  def third_party_params
    params.require(:third_party).permit(
      :party_type, :document_type, :document_number,
      :phone, :address, :first_name, :last_name, :business_name
    )
  end
end