namespace :api, defaults: {format: :json} do
  namespace :v1 do
    resource :auth
    resource :me, controller: :me
    resource :password
    resources :accounts
    resources :users
    resources :notification_tokens, param: :token, only: [:create, :destroy]
    
    # Lead submission API
    resources :lead_posts, only: [:create]
    
    # Bidding API
    resources :bid_requests do
      resources :bids, only: [:index]
      member do
        post :solicit_bids
        post :complete_bidding
      end
    end
    resources :bids, only: [:create, :show]
  end
end

resources :api_tokens
