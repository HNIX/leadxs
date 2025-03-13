class FormBuilderAnalytic < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :form_builder
  
  validates :date, presence: true, uniqueness: { scope: :form_builder_id }
  validates :views, :starts, :submissions, :completions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :total_time_on_form_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  # Add the account association via the form builder for proper tenant scoping
  delegate :account, to: :form_builder
  
  # Calculate conversion rate (submissions / views)
  def conversion_rate
    return 0 if views.zero?
    (submissions.to_f / views * 100).round(2)
  end
  
  # Calculate completion rate (completions / submissions)
  def completion_rate
    return 0 if submissions.zero?
    (completions.to_f / submissions * 100).round(2)
  end
  
  # Calculate average time on form in seconds
  def average_time_on_form
    return 0 if submissions.zero?
    (total_time_on_form_seconds.to_f / submissions).round(2)
  end
  
  # Get the fields with highest dropoff rates
  def top_dropoff_fields(limit = 5)
    return [] if field_dropoffs.blank?
    
    # Sort by dropoff count descending
    field_dropoffs.sort_by { |_, count| -count }.first(limit)
  end
  
  # Get device breakdown as percentages
  def device_breakdown_percentages
    return {} if device_breakdown.blank?
    
    total = device_breakdown.values.sum
    return {} if total.zero?
    
    device_breakdown.transform_values do |count|
      (count.to_f / total * 100).round(2)
    end
  end
  
  # Increment view count
  def increment_views!
    increment!(:views)
  end
  
  # Increment start count (when user starts filling out form)
  def increment_starts!
    increment!(:starts)
  end
  
  # Class method to aggregate analytics for a form over a date range
  def self.aggregate(form_builder, start_date, end_date)
    analytics = form_builder.analytics.where(date: start_date..end_date)
    
    # Return empty stats if no analytics found
    return empty_aggregate if analytics.empty?
    
    # Aggregate numeric fields
    views = analytics.sum(:views)
    starts = analytics.sum(:starts)
    submissions = analytics.sum(:submissions)
    completions = analytics.sum(:completions)
    total_time = analytics.sum(:total_time_on_form_seconds)
    
    # Merge field_dropoffs across all records
    field_dropoffs = {}
    analytics.each do |analytic|
      next if analytic.field_dropoffs.blank?
      
      analytic.field_dropoffs.each do |field_id, count|
        field_dropoffs[field_id] ||= 0
        field_dropoffs[field_id] += count
      end
    end
    
    # Merge device_breakdown across all records
    device_breakdown = {}
    analytics.each do |analytic|
      next if analytic.device_breakdown.blank?
      
      analytic.device_breakdown.each do |device, count|
        device_breakdown[device] ||= 0
        device_breakdown[device] += count
      end
    end
    
    # Calculate rates
    conversion_rate = views.zero? ? 0 : (submissions.to_f / views * 100).round(2)
    completion_rate = submissions.zero? ? 0 : (completions.to_f / submissions * 100).round(2)
    average_time = submissions.zero? ? 0 : (total_time.to_f / submissions).round(2)
    
    {
      date_range: {
        start_date: start_date,
        end_date: end_date,
        days: (end_date - start_date).to_i + 1
      },
      totals: {
        views: views,
        starts: starts,
        submissions: submissions,
        completions: completions,
        total_time_on_form_seconds: total_time
      },
      rates: {
        conversion_rate: conversion_rate,
        completion_rate: completion_rate,
        average_time_on_form: average_time
      },
      field_dropoffs: field_dropoffs,
      device_breakdown: device_breakdown
    }
  end
  
  # Empty aggregate result for when no data is available
  def self.empty_aggregate
    {
      date_range: nil,
      totals: {
        views: 0,
        starts: 0,
        submissions: 0,
        completions: 0,
        total_time_on_form_seconds: 0
      },
      rates: {
        conversion_rate: 0,
        completion_rate: 0,
        average_time_on_form: 0
      },
      field_dropoffs: {},
      device_breakdown: {}
    }
  end
end