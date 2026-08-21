class ApplicationController < ActionController::Base
  layout :resolve_layout

  helper_method :admin_user?, :collaborator_user?, :turbo_native_app?, :show_android_app_download?

  private

  def resolve_layout
    turbo_native_app? ? "turbo_native" : "application"
  end

  # El shell nativo (Hotwire Native / Turbo Native para Android e iOS) agrega
  # este identificador al User-Agent del WebView. Cuando la request viene de
  # ahí, se omite el layout web completo (sidebar, barra superior) porque la
  # navegación y el chrome los provee la app nativa.
  def turbo_native_app?
    request.user_agent.to_s.match?(/Turbo Native|Hotwire Native/i)
  end

  # Solo tiene sentido ofrecer el APK a alguien navegando desde un Android
  # real por fuera de la app nativa (si ya está dentro de la app, no necesita
  # instalarla).
  def show_android_app_download?
    !turbo_native_app? && request.user_agent.to_s.match?(/Android/i)
  end

  def require_admin!
    return if admin_user?
    redirect_to inspection_forms_path, alert: "No tienes permiso para acceder a esta sección."
  end

  def admin_user?
    user_signed_in? && current_user.admin?
  end

  def collaborator_user?
    user_signed_in? && current_user.collaborator?
  end
end
