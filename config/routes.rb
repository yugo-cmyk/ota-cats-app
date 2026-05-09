Rails.application.routes.draw do
  resources :cats
  # サイトを開いた瞬間に「一覧（地図付き）」を表示
  root "cats#index"
end