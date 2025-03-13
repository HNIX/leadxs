module FormBuilders
  class FormSubmissionsController < ApplicationController
    include Pagy::Backend
    
    before_action :authenticate_user!
    before_action :set_campaign
    before_action :set_form_builder
    before_action :set_submission, only: [:show, :destroy, :reprocess]
    
    def index
      submissions = @form_builder.submissions.includes(:lead).order(created_at: :desc)
      
      # Filter by status if provided
      if params[:status].present? && FormSubmission::STATUSES.include?(params[:status])
        submissions = submissions.where(status: params[:status])
      end
      
      # Paginate results using Pagy
      @pagy, @submissions = pagy(submissions, items: 25)
    end
    
    def show
      # Load lead data if associated with a lead
      @lead = @submission.lead if @submission.lead.present?
    end
    
    def destroy
      @submission.destroy
      
      respond_to do |format|
        format.html { redirect_to campaign_form_builder_form_submissions_path(@campaign, @form_builder), notice: "Form submission was successfully deleted." }
        format.json { head :no_content }
      end
    end
    
    # Reprocess a failed or rejected submission
    def reprocess
      # Only allow reprocessing failed or rejected submissions
      unless @submission.status.in?(['error', 'rejected'])
        redirect_to campaign_form_builder_form_submission_path(@campaign, @form_builder, @submission), 
          alert: "Only failed or rejected submissions can be reprocessed."
        return
      end
      
      # Reset the submission status to submitted
      @submission.update(
        status: 'submitted',
        metadata: @submission.metadata.merge(
          reprocessed_at: Time.current,
          reprocessed_by: current_user.id,
          original_status: @submission.status,
          previous_errors: @submission.metadata['error']
        )
      )
      
      # Queue the job to process the submission again
      ProcessFormSubmissionJob.perform_later(@submission.id)
      
      redirect_to campaign_form_builder_form_submission_path(@campaign, @form_builder, @submission), 
        notice: "Submission has been queued for reprocessing."
    end
    
    private
    
    def set_campaign
      @campaign = current_tenant.campaigns.find(params[:campaign_id])
    end
    
    def set_form_builder
      @form_builder = @campaign.form_builders.find(params[:form_builder_id])
    end
    
    def set_submission
      @submission = @form_builder.submissions.find(params[:id])
    end
  end
end