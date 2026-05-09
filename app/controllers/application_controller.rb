class ApplicationController < ActionController::Base
  # セキュリティチェックをスキップする魔法
  skip_forgery_protection
end
