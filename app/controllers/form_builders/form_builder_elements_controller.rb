module FormBuilders
  class FormBuilderElementsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_campaign
    before_action :set_form_builder
    before_action :set_element, only: [:show, :edit, :update, :destroy]
    
    def index
      @elements = @form_builder.elements.includes(:campaign_field).order(:position)
    end
    
    def show
    end
    
    def new
      @element = @form_builder.elements.new
      
      # Set the initial element type if provided in the URL params
      if params[:element_type].present? && FormBuilderElement::ELEMENT_TYPES.include?(params[:element_type])
        @element.element_type = params[:element_type]
      end
      
      @campaign_fields = @campaign.campaign_fields.where(hide: false, post_only: false).order(:position)
      @element_types = FormBuilderElement::ELEMENT_TYPES
    end
    
    def create
      # Debug log
      Rails.logger.debug "FormBuilderElements#create - Params: #{params.inspect}"
      
      @element = @form_builder.elements.new(element_params)
      
      # Set position to the end if not specified
      @element.position = @form_builder.elements.maximum(:position).to_i + 1 if @element.position.nil?
      
      # Debug log
      Rails.logger.debug "FormBuilderElements#create - Element: #{@element.inspect}"
      Rails.logger.debug "FormBuilderElements#create - Properties: #{@element.properties.inspect}"
      
      respond_to do |format|
        if @element.save
          format.html { redirect_to campaign_form_builder_path(@campaign, @form_builder), notice: "Form element was successfully created." }
          format.json { render :show, status: :created, location: @element }
          format.turbo_stream { render turbo_stream: turbo_stream.append('form-elements-container', partial: 'form_builders/form_builder_elements/element', locals: { element: @element }) }
        else
          @campaign_fields = @campaign.campaign_fields.where(hide: false, post_only: false).order(:position)
          @element_types = FormBuilderElement::ELEMENT_TYPES
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @element.errors, status: :unprocessable_entity }
          format.turbo_stream { render turbo_stream: turbo_stream.replace('new_element_form', partial: 'form_builders/form_builder_elements/form', locals: { element: @element }) }
        end
      end
    end
    
    def edit
      @campaign_fields = @campaign.campaign_fields.where(hide: false, post_only: false).order(:position)
      @element_types = FormBuilderElement::ELEMENT_TYPES
    end
    
    def update
      respond_to do |format|
        if @element.update(element_params)
          format.html { redirect_to campaign_form_builder_path(@campaign, @form_builder), notice: "Form element was successfully updated." }
          format.json { render :show, status: :ok, location: @element }
          format.turbo_stream { render turbo_stream: turbo_stream.replace("element_#{@element.id}", partial: 'form_builders/form_builder_elements/element', locals: { element: @element }) }
        else
          @campaign_fields = @campaign.campaign_fields.where(hide: false, post_only: false).order(:position)
          @element_types = FormBuilderElement::ELEMENT_TYPES
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @element.errors, status: :unprocessable_entity }
          format.turbo_stream { render turbo_stream: turbo_stream.replace('edit_element_form', partial: 'form_builders/form_builder_elements/form', locals: { element: @element }) }
        end
      end
    end
    
    def destroy
      @element.destroy
      
      respond_to do |format|
        format.html { redirect_to campaign_form_builder_path(@campaign, @form_builder), notice: "Form element was successfully deleted." }
        format.json { head :no_content }
        format.turbo_stream { render turbo_stream: turbo_stream.remove("element_#{@element.id}") }
      end
    end
    
    def bulk_update_positions
      position_updates = params[:positions]
      
      if position_updates.present?
        position_updates.each do |element_id, position|
          @form_builder.elements.find(element_id).update(position: position)
        end
      end
      
      respond_to do |format|
        format.html { redirect_to campaign_form_builder_path(@campaign, @form_builder), notice: "Element positions updated." }
        format.json { head :no_content }
      end
    end
    
    private
    
    def set_campaign
      @campaign = current_tenant.campaigns.find(params[:campaign_id])
    end
    
    def set_form_builder
      @form_builder = @campaign.form_builders.find(params[:form_builder_id])
    end
    
    def set_element
      @element = @form_builder.elements.find(params[:id])
    end
    
    def element_params
      # Extract and process properties
      element_attrs = params.require(:form_builder_element).permit(
        :element_type,
        :campaign_field_id,
        :position,
        :parent_element_id,
        :display_condition_element_id,
        :display_condition_operator,
        :display_condition_value,
        properties: {}
      )
      
      # Handle nested properties from the form
      if params[:form_builder_element][:properties].present?
        properties = element_attrs[:properties] || {}
        
        # Merge existing properties with new ones from form
        params[:form_builder_element][:properties].each do |key, value|
          properties[key] = value
        end
        
        element_attrs[:properties] = properties
      end
      
      element_attrs
    end
  end
end