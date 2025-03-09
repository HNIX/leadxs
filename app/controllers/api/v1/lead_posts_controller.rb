module Api
  module V1
    class LeadPostsController < Api::V1::BaseController
      skip_before_action :authenticate_api_token!, only: [:create]
      before_action :authenticate_source, only: [:create]
      
      # POST /api/v1/lead_posts
      def create
        # Authenticate source
        @campaign = @source.campaign
        
        # Create a new lead submission service
        submission_service = LeadSubmissionService.new(@source, @campaign, lead_params)
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
          render json: {
            success: false,
            message: result[:message],
            errors: result[:errors]
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
        
        # Set the current account for tenant scoping
        ActsAsTenant.current_tenant = @source.account
        
        true
      end
      
      def lead_params
        # Parse the params based on the campaign's field structure
        permitted_params = params.require(:lead).permit!
        
        # Return as a hash
        permitted_params.to_h
      end
    end
  end
end