class CompaniesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company, only: [:show, :edit, :update, :destroy]

  def index
    companies = filter_companies
    
    # Apply sorting
    companies = apply_sorting(companies)
    
    # Paginate the results with a safe per_page value
    per_page = params[:per_page].to_i
    # Set reasonable limits for pagination
    per_page = 5 unless [10, 20, 50, 100].include?(per_page)
    
    @pagy, @companies = pagy(companies, limit: per_page)
  end

  def show
  end

  def new
    @company = Company.new
  end

  def edit
  end

  def create
    @company = Company.new(company_params)

    if @company.save
      redirect_to @company, notice: "Company was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @company.update(company_params)
      redirect_to @company, notice: "Company was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @company.destroy
    redirect_to companies_path, notice: "Company was successfully destroyed."
  end

  private

  def set_company
    @company = Company.find(params[:id])
  end

  def company_params
    params.require(:company).permit(
      :name, 
      :address, 
      :city, 
      :state, 
      :zip_code, 
      :billing_cycle, 
      :payment_terms, 
      :currency, 
      :tax_id, 
      :notes, 
      :status
    )
  end
  
  def filter_companies
    # Always start with the current account's companies
    companies = Company.all
    
    # Filter by name (using bind parameters properly)
    if params[:name].present?
      name_pattern = "%#{sanitize_sql_like(params[:name])}%"
      companies = companies.where("name ILIKE ?", name_pattern)
    end
    
    # Filter by status (validate against allowed statuses)
    if params[:status].present? && %w[active inactive].include?(params[:status])
      companies = companies.where(status: params[:status])
    end
    
    # Filter by location (city or state), using bind parameters properly
    if params[:location].present?
      location_pattern = "%#{sanitize_sql_like(params[:location])}%"
      companies = companies.where("city ILIKE ? OR state ILIKE ?", location_pattern, location_pattern)
    end
    
    # Filter by billing cycle (validate against allowed cycles)
    if params[:billing_cycle].present? && Company::BILLING_CYCLES.include?(params[:billing_cycle])
      companies = companies.where(billing_cycle: params[:billing_cycle])
    end
    
    # Filter by creation date (with validation)
    if params[:date_range].present?
      case params[:date_range]
      when "7days"
        companies = companies.where("created_at >= ?", 7.days.ago)
      when "30days"
        companies = companies.where("created_at >= ?", 30.days.ago)
      when "90days"
        companies = companies.where("created_at >= ?", 90.days.ago)
      end
    end
    
    companies
  end
  
  def apply_sorting(companies)
    # Define allowed sort options
    allowed_sorts = %w[name_asc name_desc created_at_asc created_at_desc]
    
    # Default sort
    sort_param = params[:sort]
    sort_param = "created_at_desc" unless allowed_sorts.include?(sort_param)
    
    case sort_param
    when "name_asc"
      companies.order(name: :asc)
    when "name_desc"
      companies.order(name: :desc)
    when "created_at_asc"
      companies.order(created_at: :asc)
    else
      companies.order(created_at: :desc)
    end
  end
  
  # Helper method to sanitize SQL LIKE patterns
  def sanitize_sql_like(str)
    # Escape special characters used in LIKE patterns
    ActiveRecord::Base.sanitize_sql_like(str.to_s)
  end
end