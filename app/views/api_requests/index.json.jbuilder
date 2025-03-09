json.api_requests @api_requests do |api_request|
  json.id api_request.id
  json.requestable_type api_request.requestable_type
  json.requestable_id api_request.requestable_id
  json.lead_id api_request.lead_id
  json.endpoint_url api_request.endpoint_url
  json.request_method api_request.request_method
  json.response_code api_request.response_code
  json.duration_ms api_request.duration_ms
  json.successful api_request.successful?
  json.error api_request.error.present?
  json.sent_at api_request.sent_at
  json.created_at api_request.created_at
  json.campaign_id api_request.campaign&.id
  json.campaign_name api_request.campaign&.name
  json.url api_request_url(api_request, format: :json)
end

json.pagination do
  json.current_page @pagy.page
  json.total_pages @pagy.pages
  json.total_count @pagy.count
end