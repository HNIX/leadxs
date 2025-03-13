# This file contains standard fields for verticals
# It gets called from the main seeds.rb file

module Seeds
  class StandardVerticalFields
    def self.create_standard_fields(vertical)
      return unless vertical
      
      # Only create standard fields if none exist
      return if vertical.vertical_fields.count > 0
      
      # Auto Insurance standard fields
      if vertical.primary_category == "Insurance" && vertical.secondary_category == "Auto"
        create_auto_insurance_fields(vertical)
      # Home Insurance standard fields
      elsif vertical.primary_category == "Insurance" && vertical.secondary_category == "Home"
        create_home_insurance_fields(vertical)
      # Home Services standard fields
      elsif vertical.primary_category == "Home Services"
        create_home_services_fields(vertical)
      # Finance standard fields
      elsif vertical.primary_category == "Finance"
        create_finance_fields(vertical)
      # Default fields for any vertical
      else
        create_default_fields(vertical)
      end
    end
    
    private
    
    def self.create_auto_insurance_fields(vertical)
      # Create standard fields for auto insurance
      create_field(vertical, {
        name: "vehicle_year",
        label: "Vehicle Year",
        data_type: "number",
        required: true,
        ping_required: true,
        value_acceptance: "range",
        min_value: 1980,
        max_value: Time.current.year + 1
      })
      
      create_field(vertical, {
        name: "vehicle_make",
        label: "Vehicle Make",
        data_type: "text",
        required: true,
        ping_required: true
      })
      
      create_field(vertical, {
        name: "vehicle_model",
        label: "Vehicle Model",
        data_type: "text",
        required: true,
        ping_required: true
      })
      
      create_field(vertical, {
        name: "current_insured",
        label: "Currently Insured",
        data_type: "boolean",
        required: true,
        ping_required: true
      })
      
      create_field(vertical, {
        name: "incident_count",
        label: "Number of Incidents (Last 3 Years)",
        data_type: "number",
        required: true,
        ping_required: false,
        post_required: true,
        value_acceptance: "range",
        min_value: 0,
        max_value: 10
      })
      
      # Create default fields as well
      create_default_fields(vertical)
    end
    
    def self.create_home_insurance_fields(vertical)
      # Create standard fields for home insurance
      create_field(vertical, {
        name: "property_type",
        label: "Property Type",
        data_type: "text",
        required: true,
        ping_required: true,
        value_acceptance: "list"
      }, [
        { list_value: "Single Family Home" },
        { list_value: "Townhouse" },
        { list_value: "Condo" },
        { list_value: "Mobile Home" },
        { list_value: "Multi-Family" }
      ])
      
      create_field(vertical, {
        name: "year_built",
        label: "Year Built",
        data_type: "number",
        required: true,
        ping_required: true,
        value_acceptance: "range",
        min_value: 1900,
        max_value: Time.current.year
      })
      
      create_field(vertical, {
        name: "square_footage",
        label: "Square Footage",
        data_type: "number",
        required: true,
        ping_required: false,
        post_required: true
      })
      
      create_field(vertical, {
        name: "current_insured",
        label: "Currently Insured",
        data_type: "boolean",
        required: true,
        ping_required: true
      })
      
      # Create default fields as well
      create_default_fields(vertical)
    end
    
    def self.create_home_services_fields(vertical)
      # Create standard fields for home services
      create_field(vertical, {
        name: "project_type",
        label: "Project Type",
        data_type: "text",
        required: true,
        ping_required: true,
        value_acceptance: "list"
      }, [
        { list_value: "Kitchen Remodel" },
        { list_value: "Bathroom Remodel" },
        { list_value: "Basement Finishing" },
        { list_value: "Room Addition" },
        { list_value: "Deck/Patio" },
        { list_value: "Roofing" },
        { list_value: "Windows" },
        { list_value: "Siding" },
        { list_value: "HVAC" },
        { list_value: "Other" }
      ])
      
      create_field(vertical, {
        name: "property_type",
        label: "Property Type",
        data_type: "text",
        required: true,
        ping_required: true,
        value_acceptance: "list"
      }, [
        { list_value: "Single Family Home" },
        { list_value: "Townhouse" },
        { list_value: "Condo" },
        { list_value: "Mobile Home" },
        { list_value: "Multi-Family" }
      ])
      
      create_field(vertical, {
        name: "timeframe",
        label: "Project Timeframe",
        data_type: "text",
        required: true,
        ping_required: true,
        value_acceptance: "list"
      }, [
        { list_value: "Immediately" },
        { list_value: "1-3 months" },
        { list_value: "3-6 months" },
        { list_value: "6+ months" }
      ])
      
      create_field(vertical, {
        name: "budget",
        label: "Estimated Budget",
        data_type: "number",
        required: true,
        ping_required: true,
        value_acceptance: "range",
        min_value: 1000,
        max_value: 100000
      })
      
      # Create default fields as well
      create_default_fields(vertical)
    end
    
    def self.create_finance_fields(vertical)
      # Create standard fields for finance verticals
      create_field(vertical, {
        name: "loan_amount",
        label: "Loan Amount",
        data_type: "number",
        required: true,
        ping_required: true,
        value_acceptance: "range",
        min_value: 1000,
        max_value: 100000
      })
      
      create_field(vertical, {
        name: "loan_purpose",
        label: "Loan Purpose",
        data_type: "text",
        required: true,
        ping_required: true,
        value_acceptance: "list"
      }, [
        { list_value: "Debt Consolidation" },
        { list_value: "Home Improvement" },
        { list_value: "Major Purchase" },
        { list_value: "Business" },
        { list_value: "Education" },
        { list_value: "Other" }
      ])
      
      create_field(vertical, {
        name: "credit_score_range",
        label: "Credit Score Range",
        data_type: "text",
        required: true,
        ping_required: true,
        value_acceptance: "list"
      }, [
        { list_value: "Excellent (720+)" },
        { list_value: "Good (680-719)" },
        { list_value: "Fair (640-679)" },
        { list_value: "Poor (below 640)" },
        { list_value: "Unknown" }
      ])
      
      create_field(vertical, {
        name: "employment_status",
        label: "Employment Status",
        data_type: "text",
        required: true,
        ping_required: false,
        post_required: true,
        value_acceptance: "list"
      }, [
        { list_value: "Full-Time" },
        { list_value: "Part-Time" },
        { list_value: "Self-Employed" },
        { list_value: "Retired" },
        { list_value: "Unemployed" }
      ])
      
      create_field(vertical, {
        name: "annual_income",
        label: "Annual Income",
        data_type: "number",
        required: true,
        ping_required: false,
        post_required: true,
        is_pii: true
      })
      
      # Create default fields as well
      create_default_fields(vertical)
    end
    
    def self.create_default_fields(vertical)
      # These fields are added to all verticals as standard
      create_field(vertical, {
        name: "notes",
        label: "Additional Notes",
        data_type: "text",
        required: false,
        ping_required: false,
        post_required: false
      })
      
      create_field(vertical, {
        name: "timeframe",
        label: "Timeframe",
        data_type: "text",
        required: false,
        ping_required: false,
        post_required: false,
        value_acceptance: "list"
      }, [
        { list_value: "Immediately" },
        { list_value: "Within 1 week" },
        { list_value: "Within 1 month" },
        { list_value: "1-3 months" },
        { list_value: "3+ months" }
      ])
    end
    
    def self.create_field(vertical, attributes, list_values = nil)
      # Skip if field already exists
      return if vertical.vertical_fields.exists?(name: attributes[:name])
      
      # If value_acceptance is list but no list_values provided, default to 'any'
      if attributes[:value_acceptance] == "list" && (list_values.nil? || list_values.empty?)
        puts "WARNING: Field #{attributes[:name]} has value_acceptance 'list' but no list values provided. Changing to 'any'"
        attributes = attributes.merge(value_acceptance: "any")
      end
      
      # Create the field
      field = vertical.vertical_fields.create!(
        attributes.merge(account_id: vertical.account_id)
      )
      
      # Create list values if provided and field uses list validation
      if field.value_acceptance == "list" && list_values.present?
        list_values.each_with_index do |list_value, index|
          field.list_values.create!(
            list_value: list_value[:list_value],
            value_type: list_value[:value_type] || "string",
            position: index + 1,
            account_id: vertical.account_id
          )
        end
      end
      
      field
    end
  end
end