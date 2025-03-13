module Api
  module V1
    class LeadPostsController < Api::V1::BaseController
      skip_before_action :authenticate_api_token!, only: [:create]
      before_action :authenticate_source, only: [:create]
      
      # POST /api/v1/lead_posts
      def create
        # Authenticate source
        @campaign = @source.campaign
        
        # Get params and log for debugging
        params_hash = lead_params
        Rails.logger.info "Lead POST params: #{params_hash.inspect}"
        
        # Create a new lead submission service
        submission_service = LeadSubmissionService.new(@source, @campaign, params_hash)
        result = submission_service.process!
        
        if result[:success]
          render json: {
            success: true,
            lead_id: result[:lead].unique_id,
            status: result[:lead].status,
            bid_request_id: result[:bid_request]&.unique_id,
            message: result[:message]
          }, status: :created
        else
          # Add detailed debugging information
          debug_info = {
            success: false,
            message: result[:message],
            errors: result[:errors],
            request_details: {
              raw_parameters: params_hash,
              parameter_types: params_hash.transform_values { |v| v.class.name },
              required_fields: @campaign.campaign_fields.where(required: true).map { |f| f.name }
            }
          }
          
          # Log debug info
          Rails.logger.warn "Lead submission failed: #{debug_info.to_json}"
          
          # Render the error response
          render json: {
            success: false,
            message: result[:message],
            errors: result[:errors],
            debug: debug_info[:request_details] # Include debug info in the response
          }, status: :unprocessable_entity
        end
      end
      
      private
      
      def authenticate_source
        token = request.headers['X-Source-Token'] || params[:source_token]
        
        unless token.present?
          render json: { error: 'Source token is required' }, status: :unauthorized
          return false
        end
        
        @source = Source.find_by(token: token)
        
        unless @source&.active?
          render json: { error: 'Invalid or inactive source' }, status: :unauthorized
          return false
        end
        
        unless @source.can_submit_leads?
          if @source.daily_budget.present? || @source.monthly_budget.present?
            render json: { error: 'Source has reached its budget limit' }, status: :forbidden
            return false
          elsif @source.campaign.nil? || !@source.campaign.active?
            render json: { error: 'Campaign is not available for submissions' }, status: :forbidden
            return false
          else
            render json: { error: 'Source is not eligible to submit leads' }, status: :forbidden
            return false
          end
        end
        
        # Set the current account for tenant scoping
        ActsAsTenant.current_tenant = @source.account
        
        true
      end
      
      def lead_params
        # Handle different request formats
        if params[:lead].present?
          # Standard form submission with lead params
          permitted_params = params.require(:lead).permit!
          return permitted_params.to_h
        elsif request.raw_post.present?
          # Direct JSON payload
          begin
            # Parse the raw request body as JSON
            json_params = JSON.parse(request.raw_post)
            
            # Log what was received for debugging
            Rails.logger.debug "Raw lead post payload: #{json_params.inspect}"
            
            # Return the parsed JSON
            return json_params
          rescue JSON::ParserError => e
            Rails.logger.error "JSON parsing error: #{e.message}"
            return {}
          end
        else
          # No parameters found
          Rails.logger.warn "No lead parameters found in request"
          return {}
        end
      end
    end
  end
end