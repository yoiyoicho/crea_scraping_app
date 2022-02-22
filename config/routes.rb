Rails.application.routes.draw do
  root "home#top"
  get "/" => "home#top"
  get "/show" => "home#show"
  post "home/scrape" => "home#scrape"
  get "/download/:stock_id" => "home#downlaod"
  post "/destroy/:stock_id" => "home#destroy"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
