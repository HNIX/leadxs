class DistributionsController < ApplicationController
  before_action :set_distribution, only: [:show, :edit, :update, :destroy, :test_connection, :toggle_status]
  before_action :set_companies, only: [:new, :edit, :create, :update]

  def index
    # Start with base query
    @distributions = Distribution.includes(:company)
    
    # Apply filters
    @distributions = apply_filters(@distributions)
    
    # Apply sorting
    @distributions = apply_sorting(@distributions)
    
    # Paginate the results
    items_per_page = params[:per_page].present? ? params[:per_page].to_i : 10
    @pagy, @distributions = pagy(@distributions, items: items_per_page)
    
    respond_to do |format|
      format.html
      format.json { render json: @distributions }
    end
  end

  def show
    @headers = @distribution.headers
  end

  def new
    @distribution = Distribution.new
    @distribution.headers.build
  end

  def edit
    # Ensure there's at least one empty header for the form
    @distribution.headers.build if @distribution.headers.empty?
  end

  def create
    @distribution = Distribution.new(distribution_params)
    # account_id is automatically set by acts_as_tenant

    respond_to do |format|
      if @distribution.save
        format.html { redirect_to distribution_path(@distribution), notice: "Distribution was successfully created." }
        format.json { render :show, status: :created, location: @distribution }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @distribution.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @distribution.update(distribution_params)
        format.html { redirect_to distribution_path(@distribution), notice: "Distribution was successfully updated." }
        format.json { render :show, status: :ok, location: @distribution }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @distribution.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @distribution.destroy

    respond_to do |format|
      format.html { redirect_to distributions_path, notice: "Distribution was successfully deleted." }
      format.json { head :no_content }
    end
  end
  
  def test_connection
    # Placeholder for API testing functionality
    success = test_endpoint_connection(@distribution)
    
    respond_to do |format|
      if success
        format.html { redirect_to distribution_path(@distribution), notice: "Connection test was successful." }
        format.json { render json: { success: true, message: "Connection test was successful" } }
      else
        format.html { redirect_to distribution_path(@distribution), alert: "Connection test failed." }
        format.json { render json: { success: false, message: "Connection test failed" }, status: :unprocessable_entity }
      end
    end
  end
  
  def toggle_status
    new_status = @distribution.active? ? :paused : :active
    
    respond_to do |format|
      if @distribution.update(status: new_status)
        format.html { redirect_to distribution_path(@distribution), notice: "Distribution status was updated to #{new_status}." }
        format.json { render :show, status: :ok, location: @distribution }
      else
        format.html { redirect_to distribution_path(@distribution), alert: "Failed to update distribution status." }
        format.json { render json: @distribution.errors, status: :unprocessable_entity }
      end
    end
  end

  private
  
  def set_distribution
    # With acts_as_tenant, Distribution.find will automatically scope to current_account
    @distribution = Distribution.find(params[:id])
  end
  
  def set_companies
    @companies = current_account.companies.active.sorted
  end
  
  def distribution_params
    params.require(:distribution).permit(
      :name, :description, :company_id, :endpoint_url, :authentication_token,
      :request_method, :request_format, :template, :status,
      headers_attributes: [:id, :name, :value, :_destroy]
    )
  end
  
  def apply_filters(scope)
    # Filter by name
    scope = scope.where("name ILIKE ?", "%#{params[:name]}%") if params[:name].present?
    
    # Filter by status
    scope = scope.where(status: params[:status]) if params[:status].present?
    
    # Filter by company
    scope = scope.where(company_id: params[:company_id]) if params[:company_id].present?
    
    # Filter by request method
    scope = scope.where(request_method: params[:request_method]) if params[:request_method].present?
    
    # Filter by request format
    scope = scope.where(request_format: params[:request_format]) if params[:request_format].present?
    
    # Filter by bidding strategy
    scope = scope.where(bidding_strategy: params[:bidding_strategy]) if params[:bidding_strategy].present?
    
    # Filter by creation date
    scope = scope.where("created_at >= ?", Date.parse(params[:created_after])) if params[:created_after].present?
    scope = scope.where("created_at <= ?", Date.parse(params[:created_before]) + 1.day) if params[:created_before].present?
    
    scope
  end
  
  def apply_sorting(scope)
    case params[:sort_by]
    when "oldest"
      scope.order(created_at: :asc)
    when "name_asc"
      scope.order(name: :asc)
    when "name_desc"
      scope.order(name: :desc)
    when "method"
      scope.order(request_method: :asc)
    when "format"
      scope.order(request_format: :asc)
    when "status"
      scope.order(status: :asc)
    else
      # Default to newest first
      scope.order(created_at: :desc)
    end
  end
  
  def test_endpoint_connection(distribution)
    # Implementation of endpoint connection testing will go here
    # For now, we'll return a mock result
    # In real implementation, we would try to make a request to the endpoint and check the response
    true
  end
end
