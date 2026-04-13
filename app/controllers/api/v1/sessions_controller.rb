class Api::V1::SessionsController < ApplicationController
  before_action :require_user!, only: [ :destroy, :current ]

  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      audit_log!("user_login", entity: user, metadata: { user_id: user.id })
      render json: { user: { id: user.id, email: user.email } }
    else
      audit_log!("login_failed", metadata: { email: params[:email], ip_address: request.remote_ip })
      render json: { error: "Invalid credentials" }, status: :unauthorized
    end
  end

  def destroy
    audit_log!("user_logout", metadata: { user_id: current_user.id })
    session.delete(:user_id)
    head :no_content
  end

  def current
    render json: { user: { id: current_user.id, email: current_user.email } }
  end
end
