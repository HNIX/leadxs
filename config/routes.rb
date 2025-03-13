# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
Rails.application.routes.draw do
  resources :standard_fields do
    resource :positions, only: [:update], module: :standard_fields
  end
  # Compliance routes
  get "compliance", to: "compliance#index", as: :compliance
  get "compliance/dashboard", to: "compliance#dashboard", as: :compliance_dashboard
  get "compliance/report", to: "compliance#report", as: :compliance_report
  get "compliance/regulatory", to: "compliance#regulatory_report", as: :compliance_regulatory_report
  
  # Record-specific compliance routes
  get "compliance/:record_type/:record_id", to: "compliance#show", as: :compliance_show
  get "compliance/:record_type/:record_id/history", to: "compliance#history", as: :compliance_history
  match "compliance/:record_type/:record_id/consent", to: "compliance#consent", as: :compliance_consent, via: [:get, :post, :delete]
  get "compliance/:record_type/:record_id/export", to: "compliance#export", as: :compliance_export
  # Bid analytics and reporting
  resources :bid_reports, only: [:index, :show]
  
  # Economics and revenue analysis reports 
  get 'bid_economics', to: 'bid_reports#economics', as: :bid_economics_report
  get 'bid_revenue', to: 'bid_reports#revenue', as: :bid_revenue_report
  
  # Real-time bid dashboard
  get 'bid_dashboard', to: 'bid_dashboard#index', as: :bid_dashboard
  get 'bid_dashboard/real_time', to: 'bid_dashboard#real_time', as: :real_time_bid_dashboard
  
  # Campaign performance dashboard
  get 'campaign_dashboard', to: 'campaign_dashboard#index', as: :campaign_dashboard
  
  # Performance reports
  namespace :reports do
    resources :sources, only: [:index, :show]
    resources :buyers, only: [:index, :show]
  end
  
  # Campaign and distribution specific reports
  get 'bid_reports/campaign/:id', to: 'bid_reports#campaign', as: :campaign_bid_report
  get 'bid_reports/distribution/:id', to: 'bid_reports#distribution', as: :distribution_bid_report
  
  # Campaign and distribution specific economics and revenue reports
  get 'bid_economics/campaign/:id', to: 'bid_reports#campaign_economics', as: :campaign_economics_report
  get 'bid_economics/distribution/:id', to: 'bid_reports#distribution_economics', as: :distribution_economics_report
  get 'bid_revenue/campaign/:id', to: 'bid_reports#campaign_revenue', as: :campaign_revenue_report
  get 'bid_revenue/distribution/:id', to: 'bid_reports#distribution_revenue', as: :distribution_revenue_report
  # Distributions (buyers/endpoints)
  resources :distributions do
    member do
      post :test_connection
      patch :toggle_status
    end
  end
  
  # Campaign Distributions mapping
  resources :campaign_distributions, except: [:index, :new, :create] do
    resources :mapped_fields, only: [:index] do
      collection do
        patch :update_mappings
      end
    end
  end
  
  # API request logs
  resources :api_requests, only: [:index, :show] do
    member do
      post :resend
    end
  end
  
  # Activity feed
  resources :activity_feed, only: [:index]
  
  # Lead management
  resources :leads, only: [:index, :show] do
    resources :activities, controller: 'lead_activities', only: [:index, :show], as: 'activities'
    member do
      get :journey, to: 'leads#journey', as: :journey
    end
  end
  
  resources :campaigns do
    member do
      post 'sync_vertical_fields'
      get 'configure'
    end
    
    # Campaign Distributions for this campaign
    resources :campaign_distributions, path: 'distributions', only: [:index, :new, :create]
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
    
    # Filters for sources and distributions
    resources :source_filters
    resources :distribution_filters
    
    # Sources for lead acquisition
    resources :sources, shallow: true, only: [:index, :new, :create]
  end
  
  # Sources with their own routes for show, edit, update, delete actions
  resources :sources, except: [:index, :new, :create] do
    member do
      post :regenerate_token
    end
  end
  
  # Bidding system routes
  resources :bid_requests do
    collection do
      get :dashboard
    end
    
    resources :bids do
      member do
        post :accept
        post :reject
      end
    end
    
    member do
      post :solicit_bids
      post :complete_bidding
      post :expire
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
      post :apply_standard_fields
      post :sync_standard_fields
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
    get :lead_bidding_docs
    get :bid_reporting_docs
    get :lead_submission_process
    get :compliance_documentation
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
