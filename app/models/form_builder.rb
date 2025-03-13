class FormBuilder < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :campaign
  has_many :elements, -> { order(position: :asc) }, class_name: "FormBuilderElement", dependent: :destroy
  has_many :submissions, class_name: "FormSubmission", dependent: :destroy
  has_many :analytics, class_name: "FormBuilderAnalytic", dependent: :destroy
  has_many :sources
  
  STATUSES = %w[draft active paused archived].freeze
  
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :embed_token, presence: true, uniqueness: true
  
  before_validation :generate_embed_token, on: :create
  
  # Default form configuration
  DEFAULT_FORM_CONFIG = {
    layout: "standard", # standard, multistep, compact
    submit_button_text: "Submit",
    progress_indicator: true,
    show_required_indicator: true,
    field_label_position: "top", # top, left, placeholder, hidden
    allow_save_progress: false
  }.freeze
  
  # Default theme configuration
  DEFAULT_THEME_CONFIG = {
    color_primary: "#4f46e5",
    color_secondary: "#3b82f6",
    color_background: "#ffffff",
    color_text: "#333333",
    color_error: "#ef4444",
    color_success: "#10b981",
    font_family: "Inter, system-ui, sans-serif",
    border_radius: "6px",
    spacing: "normal",
    logo_url: nil,
    custom_css: nil
  }.freeze
  
  # Default tracking configuration
  DEFAULT_TRACKING_CONFIG = {
    track_time_on_form: true,
    track_field_dropoff: true,
    track_device_info: true,
    track_source_info: true,
    google_analytics_id: nil,
    facebook_pixel_id: nil,
    custom_js: nil
  }.freeze
  
  # Initialize default configurations
  after_initialize do
    self.form_config = DEFAULT_FORM_CONFIG.merge(self.form_config || {})
    self.theme_config = DEFAULT_THEME_CONFIG.merge(self.theme_config || {})
    self.tracking_config = DEFAULT_TRACKING_CONFIG.merge(self.tracking_config || {})
  end
  
  # Generate iframe embed code
  def iframe_embed_code(source = nil, host = nil)
    url_options = { host: host || default_url_host }
    
    if source.present?
      # Include source_id as a query parameter
      url_options[:source_id] = source.id
    end
    
    base_url = Rails.application.routes.url_helpers.form_builder_public_url(self.embed_token, url_options)
    
    <<~HTML
      <iframe 
        src="#{base_url}" 
        style="width: 100%; height: 600px; border: none; overflow: hidden;"
        title="#{name}"
        allow="geolocation"
      ></iframe>
    HTML
  end
  
  # Generate JavaScript embed code
  def js_embed_code(source = nil, host = nil)
    url_options = { host: host || default_url_host }
    
    # Start with token parameter
    params = { token: embed_token }
    
    # Add source_id if present
    if source.present?
      params[:source_id] = source.id
    end
    
    # Generate query string
    query_string = params.to_query
    
    # Generate the embed JS URL
    base_url = Rails.application.routes.url_helpers.form_builder_embed_js_url(url_options)
    
    <<~HTML
      <div id="swayed-form-container" data-form-id="#{embed_token}"></div>
      <script src="#{base_url}?#{query_string}" async></script>
    HTML
  end
  
  # Create an initial form layout based on campaign fields
  def initialize_from_campaign_fields
    return if elements.any?
    
    position = 0
    
    # Create header section
    elements.create!(
      element_type: "header",
      position: position,
      properties: { 
        content: "<h2>#{campaign.name}</h2><p>Please fill out the form below</p>" 
      }
    )
    position += 1
    
    # Create field elements for each campaign field that isn't post-only
    campaign.campaign_fields.where(post_only: false).order(:position).each do |field|
      next if field.hide?
      
      element_properties = {
        label: field.label,
        placeholder: field.example_value,
        required: field.required,
        help_text: field.description,
        description: field.notes.to_plain_text.presence
      }
      
      elements.create!(
        campaign_field: field,
        element_type: element_type_for_field(field),
        position: position,
        properties: element_properties
      )
      position += 1
    end
    
    # Create footer with consent text
    elements.create!(
      element_type: "consent",
      position: position,
      properties: { 
        content: "By submitting this form, I agree to receive communications and understand my data will be processed according to the Privacy Policy.",
        required: true
      }
    )
    position += 1
    
    # Create submit button
    elements.create!(
      element_type: "submit",
      position: position,
      properties: { 
        text: "Submit",
        alignment: "center"
      }
    )
  end
  
  private
  
  def generate_embed_token
    self.embed_token ||= SecureRandom.urlsafe_base64(12)
  end
  
  def element_type_for_field(field)
    case field.data_type
    when "text"
      if field.name.match?(/\b(address|street)\b/i)
        "address"
      elsif field.max_length && field.max_length > 100
        "textarea" 
      else
        "text"
      end
    when "number"
      "number"
    when "boolean"
      "checkbox"
    when "date"
      "date"
    when "email"
      "email"
    when "phone"
      "phone"
    else
      if field.value_acceptance == "list"
        field.list_values.count > 5 ? "select" : "radio"
      else
        "text"
      end
    end
  end
  
  def default_url_host
    # Try to get the host from Rails configuration
    host = Rails.application.config.action_controller.default_url_options[:host] rescue nil
    
    # If not configured, use a reasonable default based on environment
    host ||= case Rails.env
      when 'production' 
        'app.swayed.com'  # Replace with your actual production domain
      when 'staging'
        'staging.swayed.com'  # Replace with your actual staging domain
      else
        'localhost:3000'  # Default for development/test
      end
    
    host
  end
end