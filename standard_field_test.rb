#!/usr/bin/env ruby

# This script tests creating a vertical and applying standard fields
account = Account.first
puts "Using account: #{account.name}"

# Create a vertical
vertical = account.verticals.create!(
  name: "Test Vertical After Fix", 
  primary_category: "Insurance"
)
puts "Created vertical: #{vertical.name}"
puts "Vertical fields count: #{vertical.vertical_fields.count}"

puts "Vertical field details:"
vertical.vertical_fields.each do |field|
  puts "- #{field.name} (#{field.data_type})"
end

puts "Done!"