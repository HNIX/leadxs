class CalculatedFieldsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign
  before_action :set_calculated_field, only: [:show, :edit, :update, :destroy]
  
  def index
    @calculated_fields = @campaign.calculated_fields
  end
  
  def show
    @modal_title = "Calculated Field Details"
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def new
    # Ensure campaign fields are loaded for the form
    @campaign_fields = @campaign.campaign_fields.ordered
    @calculated_field = @campaign.calculated_fields.new
    @modal_title = "Add New Calculated Field"
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def create
    @calculated_field = @campaign.calculated_fields.new(calculated_field_params)
    @calculated_field.account = current_account
    
    if @calculated_field.save
      respond_to do |format|
        format.html { redirect_to campaign_calculated_field_path(@campaign, @calculated_field), notice: "Calculated field was successfully created." }
        format.turbo_stream { redirect_to campaign_configure_path(@campaign, anchor: 'calculated-fields'), notice: "Calculated field was successfully created." }
      end
    else
      # Set up any needed vars for the form
      @campaign_fields = @campaign.campaign_fields.ordered
      @modal_title = "Add New Calculated Field"
      
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end
  
  def edit
    @campaign_fields = @campaign.campaign_fields.ordered
    @modal_title = "Edit Calculated Field"
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def update
    if @calculated_field.update(calculated_field_params)
      respond_to do |format|
        format.html { redirect_to campaign_calculated_field_path(@campaign, @calculated_field), notice: "Calculated field was successfully updated." }
        format.turbo_stream { redirect_to campaign_configure_path(@campaign, anchor: 'calculated-fields'), notice: "Calculated field was successfully updated." }
      end
    else
      # Set up any needed vars for the form
      @campaign_fields = @campaign.campaign_fields.ordered
      @modal_title = "Edit Calculated Field"
      
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end
  
  def destroy
    @calculated_field.destroy
    
    respond_to do |format|
      format.html { redirect_to campaign_calculated_fields_path(@campaign), notice: "Calculated field was successfully deleted." }
      format.turbo_stream { redirect_to campaign_configure_path(@campaign, anchor: 'calculated-fields'), notice: "Calculated field was successfully deleted." }
    end
  end
  
  # Validate a formula without saving it to the database
  def validate
    formula = params[:formula]
    
    # Create a temporary calculated field for validation
    temp_field = CalculatedField.new(
      name: "Temp Field",
      formula: formula,
      campaign: @campaign,
      account: current_account
    )
    
    # Run formula cleaning which includes basic validation
    temp_field.clean_formula_content
    
    # Get sample data for validation
    sample_data = generate_sample_data
    
    validation_result = {
      valid: true,
      errors: []
    }
    
    # Check if there was an error during cleaning
    if temp_field.status == CalculatedField::STATUSES[:error]
      validation_result[:valid] = false
      validation_result[:errors] << "Syntax error: #{temp_field.error_log['error']}"
    end
    
    # Try evaluating with sample data to catch runtime errors
    begin
      temp_field.evaluate(sample_data)
    rescue => e
      validation_result[:valid] = false
      validation_result[:errors] << "Evaluation error: #{e.message}"
    end
    
    # Check for type compatibility issues
    type_errors = validate_type_compatibility(formula, sample_data)
    if type_errors.any?
      validation_result[:valid] = false
      validation_result[:errors].concat(type_errors)
    end
    
    # Check for references to undefined fields
    field_errors = validate_field_references(formula)
    if field_errors.any?
      validation_result[:valid] = false
      validation_result[:errors].concat(field_errors)
    end
    
    render json: validation_result
  end
  
  private
  
  def set_campaign
    @campaign = current_account.campaigns.find(params[:campaign_id])
  end
  
  def set_calculated_field
    @calculated_field = @campaign.calculated_fields.find(params[:id])
  end
  
  def calculated_field_params
    params.require(:calculated_field).permit(:name, :formula, :status)
  end
  
  # Generate sample data for all fields in the campaign
  def generate_sample_data
    sample_data = {}
    
    @campaign.campaign_fields.each do |field|
      sample_data[field.name] = field.generate_example_value
    end
    
    sample_data
  end
  
  # Validate that field references in the formula actually exist in the campaign
  def validate_field_references(formula)
    errors = []
    
    # Extract field references using a regex pattern
    field_refs = formula.scan(/field\(['"](.*?)['"]\)/).flatten
    campaign_field_names = @campaign.campaign_fields.pluck(:name)
    
    field_refs.each do |field_name|
      unless campaign_field_names.include?(field_name)
        errors << "Reference to undefined field: '#{field_name}'"
      end
    end
    
    errors
  end
  
  # Check for type compatibility issues in the formula
  def validate_type_compatibility(formula, sample_data)
    errors = []
    
    # Check for common patterns that might indicate type errors
    # This is a simplified version - a proper implementation would use an AST parser
    
    # Check for math operations on non-numeric fields
    math_ops = formula.scan(/(add|subtract|multiply|divide|round)\(\s*field\(['"](.*?)['"]\)/)
    math_ops.each do |op, field_name|
      field = @campaign.campaign_fields.find_by(name: field_name)
      if field && !field.number?
        errors << "Cannot perform '#{op}' on non-numeric field '#{field_name}'"
      end
    end
    
    # Check for date operations on non-date fields
    date_ops = formula.scan(/(formatDate|toDate)\(\s*field\(['"](.*?)['"]\)/)
    date_ops.each do |op, field_name|
      field = @campaign.campaign_fields.find_by(name: field_name)
      if field && !field.date?
        errors << "Cannot perform '#{op}' on non-date field '#{field_name}'"
      end
    end
    
    errors
  end
end
