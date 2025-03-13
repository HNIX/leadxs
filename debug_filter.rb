# Get the filter that's causing issues
filter = DistributionFilter.find(2)
campaign_field = filter.campaign_field

puts "Filter ##{filter.id}:"
puts "Field: #{campaign_field.name} (#{campaign_field.field_type})"
puts "Operator: #{filter.operator}"
puts "Value: #{filter.value}"
puts "Min Value: #{filter.min_value}"
puts "Max Value: #{filter.max_value}"
puts "Apply to all: #{filter.apply_to_all}"
puts "Status: #{filter.status}"

# Let's also check the actual lead data value for this field
lead = Lead.last
field_value = lead.field_value(campaign_field.id)

puts "\nLead value for this field: #{field_value.inspect}"

# Try to evaluate the filter directly
passes = filter.passes?(lead.field_values_hash)
puts "Filter passes? #{passes}"

# Display the condition being evaluated
conditions = []

case filter.operator
when 'equals'
  conditions << "#{field_value.inspect} == #{filter.value.inspect}"
when 'not_equals'
  conditions << "#{field_value.inspect} != #{filter.value.inspect}"
when 'contains'
  conditions << "#{field_value.inspect}.to_s.include?(#{filter.value.inspect})"
when 'does_not_contain'
  conditions << "!#{field_value.inspect}.to_s.include?(#{filter.value.inspect})"
when 'greater_than'
  conditions << "#{field_value.inspect}.to_f > #{filter.value.inspect}.to_f"
when 'less_than'
  conditions << "#{field_value.inspect}.to_f < #{filter.value.inspect}.to_f"
when 'between'
  conditions << "#{field_value.inspect}.to_f >= #{filter.min_value.inspect}.to_f"
  conditions << "#{field_value.inspect}.to_f <= #{filter.max_value.inspect}.to_f"
end

puts "\nCondition evaluation:"
conditions.each_with_index do |cond, i|
  begin
    result = eval(cond)
    puts "#{i+1}. #{cond} => #{result}"
  rescue => e
    puts "#{i+1}. #{cond} => ERROR: #{e.message}"
  end
end