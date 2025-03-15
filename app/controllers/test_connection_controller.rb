class TestConnectionController < ApplicationController
  before_action :set_distribution, only: [:evaluate_response]
  
  def evaluate_response
    # Parse the test response JSON
    response_json = params[:response_json]
    response_code = params[:response_code].to_i
    
    begin
      # Parse JSON if it's a string
      response_data = JSON.parse(response_json)
      
      # Evaluate the response against the distribution's response mapping
      success = @distribution.evaluate_response(response_data, response_code)
      
      # Extract error message if evaluation failed
      error_message = success ? nil : @distribution.extract_error_message(response_data, response_code)
      
      # Extract any potential ping ID
      ping_id = nil
      if @distribution.ping_id_field.present?
        ping_id = @distribution.extract_field_value(response_data, @distribution.ping_id_field)
      end
      
      render json: {
        success: success,
        error_message: error_message,
        ping_id: ping_id
      }
    rescue JSON::ParserError => e
      render json: { error: "Invalid JSON format: #{e.message}" }, status: :unprocessable_entity
    rescue => e
      render json: { error: "Evaluation error: #{e.message}" }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_distribution
    @distribution = Distribution.find(params[:id])
  end
end