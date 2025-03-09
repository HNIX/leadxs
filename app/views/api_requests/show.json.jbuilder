json.api_request do
  json.id @api_request.id
  json.requestable_type @api_request.requestable_type
  json.requestable_id @api_request.requestable_id
  json.lead_id @api_request.lead_id
  json.endpoint_url @api_request.endpoint_url
  json.request_method @api_request.request_method
  json.response_code @api_request.response_code
  json.duration_ms @api_request.duration_ms
  json.successful @api_request.successful?
  json.error @api_request.error
  json.sent_at @api_request.sent_at
  json.created_at @api_request.created_at
  json.updated_at @api_request.updated_at
  
  if @api_request.campaign
    json.campaign do
      json.id @api_request.campaign.id
      json.name @api_request.campaign.name
      json.url campaign_url(@api_request.campaign)
    end
  end
  
  if @api_request.lead
    json.lead do
      json.id @api_request.lead.id
      json.unique_id @api_request.lead.unique_id
      json.url lead_url(@api_request.lead)
    end
  end
  
  if @api_request.requestable
    json.requestable do
      json.id @api_request.requestable.id
      json.type @api_request.requestable_type
      json.name @api_request.requestable.name if @api_request.requestable.respond_to?(:name)
    end
  end
  
  json.request_payload @api_request.request_payload
  json.response_data @api_request.response_payload
end