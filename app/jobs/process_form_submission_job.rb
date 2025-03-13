class ProcessFormSubmissionJob < ApplicationJob
  queue_as :default
  
  def perform(submission_id)
    submission = FormSubmission.find_by(id: submission_id)
    return unless submission
    
    begin
      # Log the start of processing
      Rails.logger.info("Starting to process form submission ##{submission_id}")
      
      # Process the submission
      submission.process!
      
      # Log the completion
      Rails.logger.info("Completed processing form submission ##{submission_id}: #{submission.status}")
    rescue => e
      # Capture and log any exceptions
      Rails.logger.error("Error processing form submission ##{submission_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      
      # Update submission with error details
      submission.update(
        status: 'error',
        metadata: submission.metadata.merge(
          error: e.message,
          backtrace: e.backtrace.first(10),
          error_class: e.class.name,
          processing_error: true
        )
      )
    end
  end
end