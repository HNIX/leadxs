class LeadDataProcessor
  attr_reader :lead, :campaign, :data

  def initialize(lead, data = nil)
    @lead = lead
    @campaign = lead.campaign
    @data = data || lead.field_values_hash
  end

  # Main processing method that runs all data processing steps
  def process!
    normalized_data = normalize
    calculated_data = calculate_fields(normalized_data)
    enriched_data = enrich_data(calculated_data)
    
    # Return the processed data
    enriched_data
  end

  # Normalize lead data fields
  def normalize
    normalized_data = @data.dup
    
    normalize_phone_numbers(normalized_data)
    normalize_address_fields(normalized_data)
    standardize_dates(normalized_data)
    normalize_names(normalized_data)
    trim_whitespace(normalized_data)
    
    normalized_data
  end

  # Calculate values for any calculated fields
  def calculate_fields(data = @data)
    result = data.dup
    
    @campaign.calculated_fields.each do |field|
      # Skip if the formula is blank
      next if field.formula.blank?
      
      begin
        # Evaluate the formula with the current data
        value = evaluate_formula(field.formula, result)
        
        # Store the calculated value
        result[field.name] = value
      rescue => e
        Rails.logger.error("Error calculating field '#{field.name}': #{e.message}")
        result[field.name] = nil
      end
    end
    
    result
  end

  # Enrich data with additional information from external services
  def enrich_data(data = @data)
    result = data.dup
    
    # Apply configured enrichment processors
    @campaign.enrichment_processors&.each do |processor|
      case processor
      when 'geocode'
        enrich_with_geocoding(result)
      when 'email_verification'
        enrich_with_email_verification(result)
      when 'phone_verification'
        enrich_with_phone_verification(result)
      when 'fraud_detection'
        enrich_with_fraud_detection(result)
      when 'demographics'
        enrich_with_demographics(result)
      end
    end
    
    result
  end

  # Save all processed data back to the lead
  def save_processed_data!(processed_data)
    processed_data.each do |field_name, value|
      # Find the campaign field
      campaign_field = @campaign.campaign_fields.find_by(name: field_name)
      next unless campaign_field
      
      # Update existing lead data or create new
      lead_data = @lead.lead_data.find_or_initialize_by(campaign_field_id: campaign_field.id)
      lead_data.value = value
      lead_data.save!
    end
    
    # Return the lead with updated data
    @lead.reload
  end

  private

  # Normalize phone numbers to E.164 format
  def normalize_phone_numbers(data)
    # Find phone number fields (based on field type or name pattern)
    phone_fields = @campaign.campaign_fields.where("field_type = 'phone' OR name LIKE '%phone%'").pluck(:name)
    
    phone_fields.each do |field|
      next unless data[field].present?
      
      # Remove non-digit characters
      phone = data[field].to_s.gsub(/\D/, '')
      
      # Apply basic E.164 formatting for US numbers
      # In a real implementation, you might use a library like Phony or PhoneLib
      if phone.length == 10
        data[field] = "+1#{phone}"
      elsif phone.length == 11 && phone.start_with?('1')
        data[field] = "+#{phone}"
      elsif phone.start_with?('+')
        # Already in international format
        next
      else
        # Unknown format, just ensure it starts with + if it's likely a phone number
        data[field] = "+#{phone}" if phone.length >= 10
      end
    end
  end

  # Normalize address fields (proper case, etc.)
  def normalize_address_fields(data)
    # Find address fields
    address_fields = @campaign.campaign_fields.where(
      "name LIKE '%address%' OR name LIKE '%street%' OR name = 'city' OR name = 'state'"
    ).pluck(:name)
    
    address_fields.each do |field|
      next unless data[field].present?
      
      if field.include?('state') && data[field].length == 2
        # State abbreviations should be uppercase
        data[field] = data[field].upcase
      else
        # Title case for addresses and cities
        data[field] = data[field].titleize
      end
    end
    
    # Special handling for zip codes
    zip_fields = @campaign.campaign_fields.where("name LIKE '%zip%' OR name LIKE '%postal%'").pluck(:name)
    zip_fields.each do |field|
      next unless data[field].present?
      
      # Standardize US ZIP codes
      if data[field].to_s =~ /^\d{5}(-\d{4})?$/
        # Already in correct format
        next
      elsif data[field].to_s =~ /^\d{9}$/
        # Convert 9-digit ZIP to ZIP+4 format
        data[field] = "#{data[field][0..4]}-#{data[field][5..8]}"
      elsif data[field].to_s =~ /^\d{5}$/
        # Already in 5-digit format
        next
      end
    end
  end

  # Standardize date formats
  def standardize_dates(data)
    # Find date fields
    date_fields = @campaign.campaign_fields.where("field_type = 'date' OR name LIKE '%date%'").pluck(:name)
    
    date_fields.each do |field|
      next unless data[field].present?
      
      begin
        # Parse the date using a flexible date parser
        date = Chronic.parse(data[field].to_s)
        
        # Format as ISO 8601 (YYYY-MM-DD)
        data[field] = date.strftime('%Y-%m-%d') if date
      rescue
        # If parsing fails, leave the date as is
        next
      end
    end
  end

  # Normalize name fields
  def normalize_names(data)
    # Find name fields
    name_fields = @campaign.campaign_fields.where(
      "name LIKE '%name%' AND name NOT LIKE '%last%' AND name NOT LIKE '%first%'"
    ).pluck(:name)
    
    # Handle full names (not first/last)
    name_fields.each do |field|
      next unless data[field].present?
      
      # Proper case for names
      data[field] = data[field].titleize
    end
    
    # Handle first names
    first_name_fields = @campaign.campaign_fields.where("name LIKE '%first_name%' OR name = 'first'").pluck(:name)
    first_name_fields.each do |field|
      next unless data[field].present?
      
      # Proper case for first names
      data[field] = data[field].titleize
    end
    
    # Handle last names
    last_name_fields = @campaign.campaign_fields.where("name LIKE '%last_name%' OR name = 'last'").pluck(:name)
    last_name_fields.each do |field|
      next unless data[field].present?
      
      # Proper case for last names with special handling for names like "McDonald"
      data[field] = data[field].titleize.gsub(/Mc(\w)/) { "Mc#{$1.upcase}" }
    end
  end

  # Trim whitespace from all string fields
  def trim_whitespace(data)
    data.each do |field, value|
      data[field] = value.strip if value.is_a?(String)
    end
  end

  # Evaluate a formula using the lead data
  def evaluate_formula(formula, data)
    # Create a context for formula evaluation
    FormulaEvaluator.new(data).evaluate(formula)
  end

  # Enrich with geocoding information
  def enrich_with_geocoding(data)
    # Check if we have address components
    address_fields = %w[address street city state zip postal_code]
    return data unless address_fields.any? { |field| data.key?(field) && data[field].present? }
    
    # Build address string
    address = [
      data['address'] || data['street'],
      data['city'],
      data['state'],
      data['zip'] || data['postal_code']
    ].compact.join(', ')
    
    begin
      # In a real implementation, you would call a geocoding service here
      # This is a placeholder for the implementation
      # geocoder = GeocodingService.new
      # geocoding_result = geocoder.geocode(address)
      
      # Simulate a geocoding result for demonstration
      geocoding_result = {
        latitude: 37.7749,
        longitude: -122.4194,
        formatted_address: "123 Main St, San Francisco, CA 94110, USA",
        timezone: "America/Los_Angeles"
      }
      
      # Add geocoding data to the result
      data['latitude'] = geocoding_result[:latitude]
      data['longitude'] = geocoding_result[:longitude]
      data['formatted_address'] = geocoding_result[:formatted_address]
      data['timezone'] = geocoding_result[:timezone]
    rescue => e
      Rails.logger.error("Geocoding failed: #{e.message}")
    end
    
    data
  end

  # Enrich with email verification
  def enrich_with_email_verification(data)
    # Check if we have an email field
    email_field = @campaign.campaign_fields.find_by("name = 'email' OR field_type = 'email'")&.name
    return data unless email_field && data[email_field].present?
    
    begin
      # In a real implementation, you would call an email verification service
      # This is a placeholder for the implementation
      # verifier = EmailVerificationService.new
      # verification_result = verifier.verify(data[email_field])
      
      # Simulate a verification result
      verification_result = {
        valid_format: true,
        deliverable: true,
        disposable: false,
        role_account: false,
        score: 0.95
      }
      
      # Add verification data
      data['email_valid'] = verification_result[:valid_format]
      data['email_deliverable'] = verification_result[:deliverable]
      data['email_disposable'] = verification_result[:disposable]
      data['email_role_account'] = verification_result[:role_account]
      data['email_quality_score'] = verification_result[:score]
    rescue => e
      Rails.logger.error("Email verification failed: #{e.message}")
    end
    
    data
  end

  # Enrich with phone verification
  def enrich_with_phone_verification(data)
    # Check if we have a phone field
    phone_field = @campaign.campaign_fields.find_by("name LIKE '%phone%' OR field_type = 'phone'")&.name
    return data unless phone_field && data[phone_field].present?
    
    begin
      # In a real implementation, you would call a phone verification service
      # This is a placeholder for the implementation
      # verifier = PhoneVerificationService.new
      # verification_result = verifier.verify(data[phone_field])
      
      # Simulate a verification result
      verification_result = {
        valid: true,
        carrier: "Verizon",
        line_type: "mobile",
        country: "US",
        do_not_call: false
      }
      
      # Add verification data
      data['phone_valid'] = verification_result[:valid]
      data['phone_carrier'] = verification_result[:carrier]
      data['phone_type'] = verification_result[:line_type]
      data['phone_country'] = verification_result[:country]
      data['phone_dnc'] = verification_result[:do_not_call]
    rescue => e
      Rails.logger.error("Phone verification failed: #{e.message}")
    end
    
    data
  end

  # Enrich with fraud detection
  def enrich_with_fraud_detection(data)
    begin
      # In a real implementation, you would call a fraud detection service
      # This is a placeholder for the implementation
      # detector = FraudDetectionService.new
      # detection_result = detector.analyze(data)
      
      # Simulate a detection result
      detection_result = {
        risk_score: 12,
        suspicious: false,
        fraud_indicators: []
      }
      
      # Add fraud detection data
      data['fraud_score'] = detection_result[:risk_score]
      data['suspicious'] = detection_result[:suspicious]
      data['fraud_indicators'] = detection_result[:fraud_indicators]
    rescue => e
      Rails.logger.error("Fraud detection failed: #{e.message}")
    end
    
    data
  end

  # Enrich with demographic data
  def enrich_with_demographics(data)
    begin
      # In a real implementation, you would call a demographics service
      # This is a placeholder for the implementation
      # demographics = DemographicsService.new
      # demographics_result = demographics.lookup(data)
      
      # Simulate a demographics result
      demographics_result = {
        age_range: "25-34",
        gender: "unknown",
        income_range: "50k-75k",
        education_level: "college",
        homeowner: true
      }
      
      # Add demographics data
      data['demographic_age_range'] = demographics_result[:age_range]
      data['demographic_gender'] = demographics_result[:gender]
      data['demographic_income'] = demographics_result[:income_range]
      data['demographic_education'] = demographics_result[:education_level]
      data['demographic_homeowner'] = demographics_result[:homeowner]
    rescue => e
      Rails.logger.error("Demographics enrichment failed: #{e.message}")
    end
    
    data
  end
end

# Formula evaluator for calculated fields
class FormulaEvaluator
  def initialize(data)
    @data = data
  end
  
  def evaluate(formula)
    # Replace field references with actual values
    expression = formula.gsub(/field\(['"]([^'"]+)['"]\)/) do
      field_name = $1
      if @data.key?(field_name)
        value = @data[field_name]
        # Quote string values, leave numbers as is
        value.is_a?(String) ? "\"#{value.gsub('"', '\\"')}\"" : value.to_s
      else
        "nil"
      end
    end
    
    # Create a clean binding with helper methods
    context = create_binding
    
    # Evaluate the expression
    result = context.eval(expression)
    
    # Convert result to appropriate type
    convert_result(result)
  end
  
  private
  
  def create_binding
    # Create a clean binding
    binding_context = binding
    
    # Add helper modules
    string_module = Module.new do
      def self.concat(*args); args.join(''); end
      def self.uppercase(str); str.to_s.upcase; end
      def self.lowercase(str); str.to_s.downcase; end
      def self.titlecase(str); str.to_s.titleize; end
      def self.substring(str, start, length = nil); length ? str.to_s[start, length] : str.to_s[start..-1]; end
      def self.format_phone(str); str.to_s.gsub(/\D/, '').gsub(/(\d{3})(\d{3})(\d{4})/, '(\1) \2-\3'); end
    end
    
    number_module = Module.new do
      def self.add(*args); args.map(&:to_f).sum; end
      def self.subtract(a, b); a.to_f - b.to_f; end
      def self.multiply(*args); args.map(&:to_f).inject(1, :*); end
      def self.divide(a, b); b.to_f.zero? ? nil : a.to_f / b.to_f; end
      def self.round(num, precision = 0); num.to_f.round(precision); end
      def self.format_currency(num); sprintf("$%.2f", num.to_f); end
      def self.percent(num); "#{(num.to_f * 100).round(2)}%"; end
    end
    
    date_module = Module.new do
      def self.today; Date.today; end
      def self.now; Time.now; end
      def self.date_diff(date1, date2, unit = 'days')
        d1 = date1.is_a?(Date) ? date1 : Date.parse(date1.to_s)
        d2 = date2.is_a?(Date) ? date2 : Date.parse(date2.to_s)
        diff = (d2 - d1).to_i
        
        case unit.to_s.downcase
        when 'years'
          (diff / 365.25).floor
        when 'months'
          ((d2.year - d1.year) * 12) + (d2.month - d1.month)
        when 'weeks'
          (diff / 7).floor
        else
          diff
        end
      end
      
      def self.format_date(date, format = '%Y-%m-%d')
        date = date.is_a?(Date) ? date : Date.parse(date.to_s)
        date.strftime(format)
      end
      
      def self.age(birth_date)
        return nil unless birth_date
        birth = birth_date.is_a?(Date) ? birth_date : Date.parse(birth_date.to_s)
        today = Date.today
        age = today.year - birth.year
        age -= 1 if today < birth + age.years
        age
      end
    end
    
    conditional_module = Module.new do
      def self.if_then_else(condition, true_value, false_value)
        condition ? true_value : false_value
      end
      
      def self.switch(value, *cases)
        # Cases should be provided as pairs of [case_value, result]
        cases.each_slice(2) do |case_value, result|
          return result if value == case_value
        end
        
        # Return the last element as default if odd number of args
        cases.last if cases.length.odd?
      end
      
      def self.coalesce(*values)
        values.find { |v| !v.nil? && v != '' }
      end
    end
    
    # Make modules accessible
    binding_context.local_variable_set(:String, string_module)
    binding_context.local_variable_set(:Number, number_module)
    binding_context.local_variable_set(:Date, date_module)
    binding_context.local_variable_set(:If, conditional_module)
    
    binding_context
  end
  
  def convert_result(result)
    # Convert result to appropriate type based on content
    if result.is_a?(String) && result =~ /^[-+]?\d+(\.\d+)?$/
      # Numeric string - convert to float or integer
      result.include?('.') ? result.to_f : result.to_i
    else
      # Return as is
      result
    end
  end
end