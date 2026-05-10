class ApplicationController < ActionController::Base
  # 本番環境でのセキュリティチェックを適切に設定します
  protect_from_forgery with: :exception, unless: -> { Rails.env.production? }
end