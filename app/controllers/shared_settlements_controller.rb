class SharedSettlementsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_settlement, only: [:create, :destroy]

  def create
    # 1. Buscar usuario por email
    user = User.find_by(email: params[:email])

    if user.nil?
      redirect_to settlement_path(@settlement),
                  alert: 'Usuario no encontrado'
      return
    end

    # 2. Validar que no sea el propietario
    if user == @settlement.user
      redirect_to settlement_path(@settlement),
                  alert: 'No puedes compartir la liquidación contigo mismo'
      return
    end

    # 3. Validar que no esté ya compartido
    if @settlement.shared_with?(user)
      redirect_to settlement_path(@settlement),
                  alert: 'La liquidación ya está compartida con este usuario'
      return
    end

    # 4. Crear compartición
    shared_settlement = @settlement.shared_settlements.build(
      user: user,
      shared_by: current_user
    )

    if shared_settlement.save
      redirect_to settlement_path(@settlement),
                  notice: "Liquidación compartida con #{user.email}"
    else
      redirect_to settlement_path(@settlement),
                  alert: 'Error al compartir la liquidación'
    end

  rescue Mongoid::Errors::DocumentNotFound
    redirect_to settlements_path, alert: 'Liquidación no encontrada'
  rescue => e
    redirect_to settlement_path(@settlement),
                alert: "Error: #{e.message}"
  end

  def destroy
    shared_settlement = @settlement.shared_settlements.find(params[:id])
    shared_settlement.destroy

    redirect_to settlement_path(@settlement),
                notice: 'Acceso revocado exitosamente'
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to settlement_path(@settlement),
                alert: 'Registro de compartición no encontrado'
  end

  private

  def set_settlement
    @settlement = Settlement.find(params[:settlement_id])

    unless @settlement.can_edit?(current_user)
      redirect_to settlements_path,
                  alert: 'Solo el propietario puede compartir liquidaciones'
    end
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to settlements_path, alert: 'Liquidación no encontrada'
  end
end
