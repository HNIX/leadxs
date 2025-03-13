class FormBuildersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign
  before_action :set_form_builder, except: [:index, :new, :create]
  
  def index
    @form_builders = @campaign.form_builders
  end
  
  def show
    @elements = @form_builder.elements.includes(:campaign_field)
  end
  
  def new
    # Ensure campaign is ready for form building
    unless @campaign.ready_for_form_builder?
      redirect_to campaign_path(@campaign), alert: "This campaign isn't ready for form building yet. Please ensure it has required fields defined."
      return
    end
    
    @form_builder = @campaign.form_builders.new
  end
  
  def create
    @form_builder = @campaign.form_builders.new(form_builder_params)
    
    respond_to do |format|
      if @form_builder.save
        # Initialize form with default elements based on campaign fields
        @form_builder.initialize_from_campaign_fields
        
        format.html { redirect_to campaign_form_builder_path(@campaign, @form_builder), notice: "Form builder was successfully created." }
        format.json { render :show, status: :created, location: @form_builder }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @form_builder.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def edit
  end
  
  def update
    respond_to do |format|
      if @form_builder.update(form_builder_params)
        format.html { redirect_to campaign_form_builder_path(@campaign, @form_builder), notice: "Form builder was successfully updated." }
        format.json { render :show, status: :ok, location: @form_builder }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @form_builder.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def destroy
    @form_builder.destroy
    
    respond_to do |format|
      format.html { redirect_to campaign_form_builders_path(@campaign), notice: "Form builder was successfully deleted." }
      format.json { head :no_content }
    end
  end
  
  def preview
    render :preview, layout: 'minimal'
  end
  
  def embed_codes
    @source = Source.find(params[:source_id]) if params[:source_id].present?
  end
  
  def toggle_status
    new_status = params[:status]
    
    if FormBuilder::STATUSES.include?(new_status)
      @form_builder.update(status: new_status)
      redirect_to campaign_form_builder_path(@campaign, @form_builder), notice: "Form status updated to #{new_status}."
    else
      redirect_to campaign_form_builder_path(@campaign, @form_builder), alert: "Invalid status: #{new_status}"
    end
  end
  
  private
  
  def set_campaign
    @campaign = current_tenant.campaigns.find(params[:campaign_id])
  end
  
  def set_form_builder
    @form_builder = @campaign.form_builders.find(params[:id])
  end
  
  def form_builder_params
    params.require(:form_builder).permit(
      :name, 
      :status,
      form_config: [
        :layout, 
        :submit_button_text, 
        :progress_indicator, 
        :show_required_indicator, 
        :field_label_position,
        :allow_save_progress
      ],
      theme_config: [
        :color_primary, 
        :color_secondary, 
        :color_background, 
        :color_text, 
        :color_error, 
        :color_success,
        :font_family,
        :border_radius,
        :spacing,
        :logo_url,
        :custom_css
      ],
      tracking_config: [
        :track_time_on_form,
        :track_field_dropoff,
        :track_device_info,
        :track_source_info,
        :google_analytics_id,
        :facebook_pixel_id,
        :custom_js
      ]
    )
  end
end