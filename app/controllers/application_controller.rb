class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Pundit::Authorization

  attr_reader :current_user

  rescue_from AuthenticationError, with: :render_auth_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

  around_action :set_audit_context, if: :current_user

  private

  def set_audit_context
    RequestStore.store[:audit_user] = @current_user
    RequestStore.store[:audit_request] = request
    yield
  ensure
    RequestStore.store[:audit_user] = nil
    RequestStore.store[:audit_request] = nil
  end

  def authenticate_user!
    @current_user = User.find_by(id: session[:user_id])
    raise AuthenticationError, "Not authenticated" unless @current_user
  end

  def require_user!
    authenticate_user!
  end

  def render_auth_error(exception)
    render json: { error: exception.message }, status: :unauthorized
  end

  def render_not_found(exception)
    render json: { error: "Not found" }, status: :not_found
  end

  def render_forbidden(exception)
    render json: { error: "Forbidden" }, status: :forbidden
  end

  def audit_log!(action, entity: nil, metadata: {})
    AuditLog.log!(
      user: @current_user,
      action: action,
      entity: entity,
      metadata: metadata,
      request: request
    )
  rescue StandardError => e
    Rails.logger.error("[AuditLog] Failed to log: #{e.message}")
  end
end
