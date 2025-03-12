class VerticalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_vertical, only: [:show, :edit, :update, :destroy, :archive, :unarchive, :apply_standard_fields, :sync_standard_fields]

  def index
    @verticals = filter_verticals
    @verticals = apply_sorting(@verticals)
    
    # Paginate the results if needed
    if defined?(Pagy)
      @pagy, @verticals = pagy(@verticals, items: params[:per_page].to_i.positive? ? [params[:per_page].to_i, 100].min : 20)
    end
  end

  def show
  end

  def new
    @vertical = Vertical.new
    @vertical.base = false
  end

  def edit
  end

  def create
    @vertical = Vertical.new(vertical_params)
    @vertical.base = false # User-created verticals can't be base verticals

    if @vertical.save
      redirect_to @vertical, notice: "Vertical was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @vertical.update(vertical_params)
      redirect_to @vertical, notice: "Vertical was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vertical.destroy
    redirect_to verticals_path, notice: "Vertical was successfully deleted."
  end

  def archive
    @vertical.update(archived: true)
    redirect_to verticals_path, notice: "Vertical was successfully archived."
  end

  def unarchive
    @vertical.update(archived: false)
    redirect_to verticals_path, notice: "Vertical was successfully unarchived."
  end
  
  def apply_standard_fields
    # Use the same method from StandardField to apply standard fields to this vertical
    standard_field_count = StandardField.apply_to_vertical(@vertical)
    
    if standard_field_count > 0
      redirect_to vertical_vertical_fields_path(@vertical), notice: "#{standard_field_count} standard fields were successfully applied to this vertical."
    else
      redirect_to vertical_vertical_fields_path(@vertical), notice: "No new standard fields were applied. All standard fields are already present."
    end
  end
  
  def sync_standard_fields
    # This will re-sync any changes to existing standard fields with vertical fields
    updated_count = StandardField.sync_with_vertical(@vertical)
    
    if updated_count > 0
      redirect_to vertical_vertical_fields_path(@vertical), notice: "#{updated_count} standard fields were successfully synchronized with this vertical."
    else
      redirect_to vertical_vertical_fields_path(@vertical), notice: "No fields needed synchronization. All standard fields are up to date."
    end
  end

  private

  def set_vertical
    @vertical = Vertical.find(params[:id])
  end

  def vertical_params
    params.require(:vertical).permit(:name, :primary_category, :secondary_category, :description)
  end
  
  def filter_verticals
    verticals = Vertical.all
    
    # Filter by name
    if params[:name].present?
      name_pattern = "%#{ActiveRecord::Base.sanitize_sql_like(params[:name])}%"
      verticals = verticals.where("name ILIKE ?", name_pattern)
    end
    
    # Filter by category
    if params[:category].present?
      verticals = verticals.where(primary_category: params[:category])
    end
    
    # Filter by status
    case params[:status]
    when "active"
      verticals = verticals.active
    when "archived"
      verticals = verticals.where(archived: true)
    else
      # For "all" or nil, use show_archived param for backward compatibility
      verticals = verticals.active unless params[:show_archived] == "true"
    end
    
    verticals
  end
  
  def apply_sorting(verticals)
    # Default sorting is by name
    verticals.sorted
  end
end
