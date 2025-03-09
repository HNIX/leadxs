class DistributionsController < ApplicationController
  before_action :set_distribution, only: [:show, :edit, :update, :destroy, :test_connection, :toggle_status]
  before_action :set_companies, only: [:new, :edit, :create, :update]

  def index
    # With acts_as_tenant, we can just query Distribution directly
    @distributions = Distribution.includes(:company).order(:name)
    
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
  
  def test_endpoint_connection(distribution)
    # Implementation of endpoint connection testing will go here
    # For now, we'll return a mock result
    # In real implementation, we would try to make a request to the endpoint and check the response
    true
  end
end
