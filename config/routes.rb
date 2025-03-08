# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
Rails.application.routes.draw do
  resources :campaigns do
    resources :campaign_fields do
      resource :positions, only: [:update], module: :campaign_fields
    end
    
    # Get fields in JSON format for the formula editor
    get 'fields', to: 'campaign_fields#index', defaults: { format: :json }
    
    # Validation rules at the campaign level (new approach)
    resources :validation_rules do
      resource :positions, only: [:update], module: :validation_rules
      member do
        patch :toggle_active
      end
      collection do
        post :test
      end
    end
    
    resources :calculated_fields do
      collection do
        post :validate
      end
    end
  end

  draw :accounts
  draw :api
  draw :billing
  draw :hotwire_native
  draw :users
  draw :dev if Rails.env.local?

  authenticated :user, lambda { |u| u.admin? } do
    draw :madmin
  end

  resources :announcements, only: [:index, :show]
  resources :companies do
    resources :contacts
  end
  
  resources :verticals do
    member do
      patch :archive
      patch :unarchive
    end

    resources :vertical_fields do
      resource :positions, only: [:update], module: :vertical_fields
    end
    
    # Validation rules at the vertical level (new approach)
    resources :validation_rules do
      resource :positions, only: [:update], module: :validation_rules
      member do
        patch :toggle_active
      end
      collection do
        post :test
      end
    end
  end

  namespace :action_text do
    resources :embeds, only: [:create], constraints: {id: /[^\/]+/} do
      collection do
        get :patterns
      end
    end
  end

  scope controller: :static do
    get :about
    get :terms
    get :privacy
    get :pricing
    get :reset_app
  end
  
  # Validation rules documentation
  get 'validation_rules/documentation', to: 'validation_rules#documentation', as: :validation_rules_documentation

  match "/404", via: :all, to: "errors#not_found"
  match "/500", via: :all, to: "errors#internal_server_error"

  authenticated :user do
    root to: "dashboard#show", as: :user_root
    # Alternate route to use if logged in users should still see public root
    # get "/dashboard", to: "dashboard#show", as: :user_root
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Public marketing homepage
  root to: "static#index"
end
