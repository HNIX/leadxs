class FormBuilderPublicController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:submit]
  # Skip authentication for public forms
  skip_before_action :authenticate_user!, raise: false
  layout 'minimal'
  
  # ApplicationController already includes SetCurrentRequestDetails
  
  def show
    # Use unscoped to bypass tenant restrictions for public access
    @form_builder = FormBuilder.unscoped.find_by!(embed_token: params[:token])
    # Set the current tenant manually based on the form
    ActsAsTenant.current_tenant = @form_builder.account
    
    # Set theme variables
    @theme = @form_builder.theme_config
    
    # Only show active forms
    unless @form_builder.status == 'active'
      render :inactive_form and return
    end
    
    @elements = @form_builder.elements.includes(:campaign_field).order(:position)
    
    # Log source ID for debugging
    Rails.logger.debug "Source ID from params: #{params[:source_id].inspect}"
    
    # Find the source and handle both string and numeric IDs
    if params[:source_id].present?
      source_id = params[:source_id]
      source_id = source_id.to_i if source_id.is_a?(String) && source_id.match?(/^\d+$/)
      @source = Source.find_by(id: source_id)
      Rails.logger.debug "Found source: #{@source.inspect}"
    end
    
    # Track form view for analytics
    if @form_builder.tracking_config['track_time_on_form']
      date = Date.current
      analytics = @form_builder.analytics.find_or_initialize_by(date: date)
      analytics.increment_views!
    end
  end
  
  def submit
    # Ensure request details are set for the lead submission service
    Current.ip_address = request.ip
    Current.user_agent = request.user_agent
    
    # Use unscoped to bypass tenant restrictions for public access
    @form_builder = FormBuilder.unscoped.find_by!(embed_token: params[:token])
    # Set the current tenant manually based on the form
    ActsAsTenant.current_tenant = @form_builder.account
    
    # Only accept submissions for active forms
    unless @form_builder.status == 'active'
      render json: { success: false, error: 'This form is no longer active' }, status: :unprocessable_entity and return
    end
    
    # Debug source ID
    Rails.logger.debug "Form submission source_id from params: #{params[:source_id].inspect}"
    
    # Handle source ID properly - ensure it's not wrapped in quotes
    source_id = params[:source_id]
    if source_id.is_a?(String) && source_id.match?(/^['"](\d+)['"]$/)
      source_id = source_id.gsub(/^['"]|['"]$/, '')
      Rails.logger.debug "Cleaned source_id: #{source_id}"
    end
    
    # Find the source to verify it exists and get its token
    source = nil
    if source_id.present?
      # Try direct lookup first
      source = Source.find_by(id: source_id)
      
      # If that fails, try as integer
      if source.nil? && source_id.match?(/^\d+$/)
        source = Source.find_by(id: source_id.to_i)
      end
      
      # Return error if source not found
      unless source
        render json: { success: false, error: "Invalid source ID" }, status: :unprocessable_entity and return
      end
      
      # Return error if source not active
      unless source.active?
        render json: { success: false, error: "Source is not active" }, status: :unprocessable_entity and return
      end
      
      # Store the token for later use in form submission processing
      Rails.logger.debug "Found source #{source.id} with token: #{source.token[0..5]}..."
    else
      render json: { success: false, error: "Source ID is required" }, status: :unprocessable_entity and return
    end
    
    # Create form submission record
    @submission = FormSubmission.new(
      form_builder: @form_builder,
      form_data: params[:form_data] || {},
      metadata: {
        source_id: source.id,
        source_token: source.token, # Store the token securely in the metadata
        referrer: request.referrer,
        time_data: params[:time_data],
        device_info: params[:device_info]
      },
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      consent_text: params[:consent_text]
    )
    
    if @submission.save
      # Process the submission asynchronously
      ProcessFormSubmissionJob.perform_later(@submission.id)
      
      # Track submission for analytics
      @submission.track_analytics!
      
      render json: { 
        success: true, 
        submission_id: @submission.id,
        redirect_url: params[:redirect_url].presence || form_builder_public_success_path(@form_builder.embed_token)
      }
    else
      render json: { success: false, errors: @submission.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def success
    # Use unscoped to bypass tenant restrictions for public access
    @form_builder = FormBuilder.unscoped.find_by!(embed_token: params[:token])
    # Set the current tenant manually based on the form
    ActsAsTenant.current_tenant = @form_builder.account
    @theme = @form_builder.theme_config
  end
  
  def error
    # Use unscoped to bypass tenant restrictions for public access
    @form_builder = FormBuilder.unscoped.find_by!(embed_token: params[:token])
    # Set the current tenant manually based on the form
    ActsAsTenant.current_tenant = @form_builder.account
    @theme = @form_builder.theme_config
    @error_message = params[:message] || "There was an error processing your submission."
  end
  
  def embed_js
    # Use unscoped to bypass tenant restrictions for public access
    @form_builder = FormBuilder.unscoped.find_by!(embed_token: params[:token])
    # Set the current tenant manually based on the form
    ActsAsTenant.current_tenant = @form_builder.account
    
    # Set CORS headers
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, X-Requested-With'
    
    render js: generate_embed_js, content_type: 'application/javascript'
  end
  
  private
  
  def generate_embed_js
    # This method would generate the JavaScript code for embedding the form
    # For a production implementation, this would be better served as a precompiled asset
    <<~JS
      (function() {
        // Create iframe and inject into specified container
        const container = document.getElementById('swayed-form-container');
        if (!container) {
          console.error('Swayed form container not found');
          return;
        }
        
        const formId = container.getAttribute('data-form-id');
        if (!formId) {
          console.error('Form ID not specified');
          return;
        }
        
        // Create iframe
        const iframe = document.createElement('iframe');
        let formUrl = '#{form_builder_public_url(':token')}'.replace(':token', formId);
        
        // Check if source_id was passed in the script URL
        const sourceId = new URLSearchParams(document.currentScript.src.split('?')[1]).get('source_id');
        if (sourceId) {
          formUrl += (formUrl.includes('?') ? '&' : '?') + 'source_id=' + sourceId;
        }
        
        iframe.src = formUrl;
        iframe.style.width = '100%';
        iframe.style.height = '600px';
        iframe.style.border = 'none';
        iframe.style.overflow = 'hidden';
        iframe.setAttribute('title', 'Swayed Lead Form');
        iframe.setAttribute('allow', 'geolocation');
        
        // Add responsive sizing
        window.addEventListener('message', function(event) {
          if (event.data && event.data.type === 'swaped-form-resize') {
            iframe.style.height = event.data.height + 'px';
          }
        });
        
        // Add iframe to container
        container.innerHTML = '';
        container.appendChild(iframe);
      })();
    JS
  end
end