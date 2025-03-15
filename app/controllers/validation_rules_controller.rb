class ValidationRulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_validatable, except: [:documentation]
  before_action :set_validation_rule, only: [:show, :edit, :update, :destroy, :toggle_active]
  
  def index
    @validation_rules = @validatable.validation_rules.ordered
  end
  
  def show

  end
  
  def new
    @validation_rule = @validatable.validation_rules.new
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def create
    @validation_rule = @validatable.validation_rules.new(validation_rule_params)
    @validation_rule.account = current_account

    if @validation_rule.save
      respond_to do |format|
        format.html { redirect_to polymorphic_path([@validatable, @validation_rule]), notice: "Validation rule was successfully created." }
        format.turbo_stream do
          if @validatable.is_a?(Campaign)
            flash.now[:notice] = "Validation rule was successfully created."
            render turbo_stream: [
              turbo_stream.update("modal", ""),
              turbo_stream.replace("validation-rules-container", 
                partial: "validation_rules/validation_rules_table", 
                locals: { validation_rules: @validatable.validation_rules.ordered }
              ),
              turbo_stream.replace("flash", partial: "application/flash")
            ]
          else
            redirect_to polymorphic_path([@validatable, :validation_rules]), notice: "Validation rule was successfully created."
          end
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end
  
  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def update
    if @validation_rule.update(validation_rule_params)
      respond_to do |format|
        format.html { redirect_to polymorphic_path([@validatable, @validation_rule]), notice: "Validation rule was successfully updated." }
        format.turbo_stream do
          if @validatable.is_a?(Campaign)
            flash.now[:notice] = "Validation rule was successfully updated."
            render turbo_stream: [
              turbo_stream.update("modal", ""),
              turbo_stream.replace("validation-rules-container", 
                partial: "validation_rules/validation_rules_table", 
                locals: { validation_rules: @validatable.validation_rules.ordered }
              ),
              turbo_stream.replace("flash", partial: "application/flash")
            ]
          else
            redirect_to polymorphic_path([@validatable, :validation_rules]), notice: "Validation rule was successfully updated."
          end
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end
  
  def destroy
    @validation_rule.destroy
    
    respond_to do |format|
      format.html do
        # For campaign or vertical validation rules, return to the appropriate index
        if @validatable.is_a?(Campaign)
          redirect_to campaign_validation_rules_path(@validatable), notice: "Validation rule was successfully deleted."
        elsif @validatable.is_a?(Vertical)
          redirect_to vertical_validation_rules_path(@validatable), notice: "Validation rule was successfully deleted."
        else
          # Legacy support for field-level rules
          redirect_to polymorphic_path([@validatable.is_a?(VerticalField) ? @validatable.vertical : @validatable.campaign, @validatable, :validation_rules]), 
                    notice: "Validation rule was successfully deleted."
        end
      end
      
      format.turbo_stream do
        if @validatable.is_a?(Campaign)
          # If deleted from campaign configure page via modal, update the table
          flash.now[:notice] = "Validation rule was successfully deleted."
          render turbo_stream: [
            turbo_stream.update("modal", ""),
            turbo_stream.replace("validation-rules-container", 
              partial: "validation_rules/validation_rules_table", 
              locals: { validation_rules: @validatable.validation_rules.ordered }
            ),
            turbo_stream.replace("flash", partial: "application/flash")
          ]
        else
          # For other cases, redirect normally
          redirect_to polymorphic_path([@validatable, :validation_rules]), notice: "Validation rule was successfully deleted."
        end
      end
    end
  end
  
  def toggle_active
    @validation_rule.update(active: !@validation_rule.active)
    
    respond_to do |format|
      format.html do
        # For campaign or vertical validation rules, return to the appropriate index
        if @validatable.is_a?(Campaign)
          redirect_to campaign_validation_rules_path(@validatable), 
                    notice: "Validation rule was successfully #{@validation_rule.active? ? 'activated' : 'deactivated'}."
        elsif @validatable.is_a?(Vertical)
          redirect_to vertical_validation_rules_path(@validatable), 
                    notice: "Validation rule was successfully #{@validation_rule.active? ? 'activated' : 'deactivated'}."
        else
          # Legacy support for field-level rules
          redirect_to polymorphic_path([@validatable.is_a?(VerticalField) ? @validatable.vertical : @validatable.campaign, @validatable, :validation_rules]), 
                    notice: "Validation rule was successfully #{@validation_rule.active? ? 'activated' : 'deactivated'}."
        end
      end
      
      format.turbo_stream do
        if @validatable.is_a?(Campaign)
          # If toggled from campaign configure page via modal, update the table
          flash.now[:notice] = "Validation rule was successfully #{@validation_rule.active? ? 'activated' : 'deactivated'}."
          render turbo_stream: [
            turbo_stream.update("modal", ""),
            turbo_stream.replace("validation-rules-container", 
              partial: "validation_rules/validation_rules_table", 
              locals: { validation_rules: @validatable.validation_rules.ordered }
            ),
            turbo_stream.replace("flash", partial: "application/flash")
          ]
        else
          # For other cases, redirect normally
          redirect_to polymorphic_path([@validatable, :validation_rules]), notice: "Validation rule was successfully #{@validation_rule.active? ? 'activated' : 'deactivated'}."
        end
      end
    end
  end
  
  def documentation
    # Displays the validation rules documentation
    # No specific data needed for this action
  end
  
  def test
    # Test a validation rule with provided data
    test_data = params[:test_data].to_unsafe_h
    rule_params = params[:validation_rule]
    
    # Create a temporary validation rule for testing
    temp_rule = ValidationRule.new(
      rule_type: rule_params[:rule_type],
      validatable: @validatable,
      account: current_account,
      name: rule_params[:name],
      condition: rule_params[:condition],
      error_message: rule_params[:error_message],
      parameters: JSON.parse(rule_params[:parameters] || '{}')
    )
    
    # Evaluate the rule with the test data
    result = temp_rule.evaluate(test_data)
    
    # Return the result as JSON
    render json: result
  end
  
  private
  
  def set_validatable
    
    if params[:campaign_id]
      # New approach: campaign-level validations
      @campaign = Campaign.find(params[:campaign_id])
      @validatable = @campaign
    elsif params[:vertical_id]
      # New approach: vertical-level validations
      @vertical = Vertical.find(params[:vertical_id])
      @validatable = @vertical
    else
      raise ActionController::RoutingError.new('Not Found')
    end
  end
  
  def set_validation_rule
    if @campaign && !params[:campaign_field_id]
      # Campaign-level validations
      @validation_rule = @campaign.validation_rules.find(params[:id])
    elsif @vertical && !params[:vertical_field_id]
      # Vertical-level validations
      @validation_rule = @vertical.validation_rules.find(params[:id])
    else
      # Legacy: field-level validations
      @validation_rule = @validatable.validation_rules.find(params[:id])
    end
  end
  
  def validation_rule_params
    params.require(:validation_rule).permit(
      :rule_type, 
      :name, 
      :description, 
      :condition, 
      :error_message, 
      :severity,
      :test_data, 
      :parameters, 
      :active,
      parameters: {}
    )
  end
end
