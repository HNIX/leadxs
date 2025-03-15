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
    # Test the distribution endpoint connection
    test_result = test_endpoint_connection(@distribution)
    
    respond_to do |format|
      if test_result[:success]
        format.html { redirect_to distribution_path(@distribution), notice: "Connection test was successful. Response code: #{test_result[:code]}" }
        format.json { render json: { success: true, message: test_result[:message], code: test_result[:code], response_time: test_result[:response_time] } }
      else
        format.html { redirect_to distribution_path(@distribution), alert: "Connection test failed: #{test_result[:message]}" }
        format.json { render json: { success: false, message: test_result[:message] }, status: :unprocessable_entity }
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
      :request_method, :request_format, :template, :status, :endpoint_type,
      :authentication_method, :username, :password, :api_key_name, :api_key_location,
      :client_id, :client_secret, :token_url, :refresh_token, :post_endpoint_url,
      :bid_endpoint_url, :bidding_strategy, :base_bid_amount, :min_bid_amount, :max_bid_amount,
      :ping_id_field, :ping_id_target_field, :response_mapping,
      headers_attributes: [:id, :name, :value, :_destroy],
      request_mapping: {}
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
    require 'net/http'
    require 'uri'
    require 'json'
    
    begin
      # Start timing
      start_time = Time.now
      
      # Select the appropriate endpoint URL
      endpoint_url = distribution.endpoint_url
      
      # Parse the URL
      uri = URI.parse(endpoint_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 10 # 10 seconds timeout
      
      # Create a test payload with minimal data
      test_payload = {
        test: true,
        timestamp: Time.now.utc.iso8601,
        source: "LeadXS Distribution Test"
      }
      
      # Create request based on method
      request = case distribution.request_method
                when "get"
                  uri.query = URI.encode_www_form(test_payload) if test_payload.is_a?(Hash)
                  Net::HTTP::Get.new(uri)
                when "post"
                  req = Net::HTTP::Post.new(uri)
                  set_test_payload(req, distribution, test_payload)
                  req
                when "put"
                  req = Net::HTTP::Put.new(uri)
                  set_test_payload(req, distribution, test_payload)
                  req
                when "patch"
                  req = Net::HTTP::Patch.new(uri)
                  set_test_payload(req, distribution, test_payload)
                  req
                end
      
      # Apply authentication
      apply_test_authentication(request, distribution)
      
      # Add headers
      distribution.headers.each do |header|
        request[header.name] = header.value
      end
      
      # Send the request
      response = http.request(request)
      
      # Calculate response time
      response_time = (Time.now - start_time) * 1000 # ms
      
      # Check if response is success (2xx status code)
      success = (200..299).include?(response.code.to_i)
      
      {
        success: success,
        code: response.code.to_i,
        message: "Received HTTP #{response.code} in #{response_time.round(2)}ms",
        response_time: response_time.round(2),
        body: response.body.truncate(1000) # Truncate long responses
      }
    rescue => e
      {
        success: false,
        message: "Error: #{e.message}",
        code: nil,
        response_time: nil
      }
    end
  end
  
  def set_test_payload(request, distribution, payload)
    case distribution.request_format
    when "json"
      request.content_type = 'application/json'
      request.body = payload.to_json
    when "xml"
      request.content_type = 'application/xml'
      xml_content = payload.map { |k, v| "<#{k}>#{v}</#{k}>" }.join
      request.body = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><test>#{xml_content}</test>"
    when "form"
      request.content_type = 'application/x-www-form-urlencoded'
      request.set_form_data(payload)
    end
  end
  
  def apply_test_authentication(request, distribution)
    if distribution.authentication_method_token?
      if distribution.api_key_location == "header"
        request[distribution.api_key_name] = distribution.authentication_token
      else
        # Add to query params for GET or as part of body for other methods
        # Implementation depends on payload structure
      end
    elsif distribution.authentication_method_basic_auth?
      if distribution.username.present? && distribution.password.present?
        request.basic_auth(distribution.username, distribution.password)
      end
    elsif distribution.authentication_method_oauth2?
      if distribution.access_token.present?
        request["Authorization"] = "Bearer #{distribution.access_token}"
      elsif distribution.client_id.present? && distribution.client_secret.present? && distribution.token_url.present?
        # We could try to get a token here, but for a connection test we'll just report that OAuth is configured
        # but no token is available
      end
    end
  end
end
