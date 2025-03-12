# Standard fields for each account
# These fields will be automatically added to all newly created verticals

# Find all accounts
Account.find_each do |account|
  puts "Setting up standard fields for account: #{account.name}"
  
  # Skip if standard fields already exist
  if account.standard_fields.exists?
    puts "Standard fields already exist for this account, skipping..."
    next
  end
  
  # Create standard fields
  standard_fields = [
    # Contact information fields
    {
      name: "first_name",
      label: "First Name",
      data_type: :text,
      value_acceptance: :any,
      required: true,
      is_pii: true,
      ping_required: true,
      post_required: true,
      post_only: false,
      min_length: 2,
      max_length: 50,
      description: "Customer's first name",
      position: 1
    },
    {
      name: "last_name",
      label: "Last Name",
      data_type: :text,
      value_acceptance: :any,
      required: true,
      is_pii: true,
      ping_required: true,
      post_required: true,
      post_only: false,
      min_length: 2,
      max_length: 50,
      description: "Customer's last name",
      position: 2
    },
    {
      name: "email",
      label: "Email Address",
      data_type: :email,
      value_acceptance: :any,
      required: true,
      is_pii: true,
      ping_required: false,
      post_required: true,
      post_only: true,
      description: "Customer's email address",
      position: 3
    },
    {
      name: "phone",
      label: "Phone Number",
      data_type: :phone,
      value_acceptance: :any,
      required: true,
      is_pii: true,
      ping_required: false,
      post_required: true,
      post_only: true,
      description: "Customer's phone number in E.164 format",
      position: 4
    },
    # Address fields
    {
      name: "address_line1",
      label: "Address Line 1",
      data_type: :text,
      value_acceptance: :any,
      required: false,
      is_pii: true,
      ping_required: false,
      post_required: false,
      post_only: true,
      description: "Street address, PO box, company name",
      position: 5
    },
    {
      name: "address_line2",
      label: "Address Line 2",
      data_type: :text,
      value_acceptance: :any,
      required: false,
      is_pii: true,
      ping_required: false,
      post_required: false,
      post_only: true,
      description: "Apartment, suite, unit, building, floor, etc.",
      position: 6
    },
    {
      name: "city",
      label: "City",
      data_type: :text,
      value_acceptance: :any,
      required: false,
      is_pii: true,
      ping_required: false,
      post_required: false,
      post_only: true,
      description: "City/Town",
      position: 7
    },
    {
      name: "state",
      label: "State",
      data_type: :text,
      value_acceptance: :any,
      required: false,
      is_pii: true,
      ping_required: false,
      post_required: false,
      post_only: true,
      max_length: 2,
      description: "State (2 letter code)",
      position: 8
    },
    {
      name: "zip_code",
      label: "ZIP Code",
      data_type: :text,
      value_acceptance: :any,
      required: false,
      is_pii: true,
      ping_required: false,
      post_required: false,
      post_only: true,
      description: "ZIP/Postal code",
      position: 9
    },
    # Consent fields
    {
      name: "tcpa_consent",
      label: "TCPA Consent",
      data_type: :boolean,
      value_acceptance: :any,
      required: true,
      is_pii: false,
      ping_required: true,
      post_required: true,
      post_only: false,
      description: "Consumer has provided TCPA consent for contact",
      position: 10
    },
    {
      name: "consent_timestamp",
      label: "Consent Timestamp",
      data_type: :text,
      value_acceptance: :any,
      required: true,
      is_pii: false,
      ping_required: true,
      post_required: true,
      post_only: false,
      description: "Timestamp when consent was provided (ISO 8601 format)",
      position: 11
    }
  ]
  
  # Create standard fields
  standard_fields.each do |field_attrs|
    account.standard_fields.create!(field_attrs.merge(account: account))
  end
  
  puts "Created #{standard_fields.length} standard fields for account: #{account.name}"
end