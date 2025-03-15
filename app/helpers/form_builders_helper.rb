module FormBuildersHelper
  # Generate breadcrumbs for the form builders index page
  def form_builders_index_breadcrumbs(campaign)
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: campaign.name, path: campaign_path(campaign) },
          { title: "Form Builders", active: true }
        ]
      }
    end
  end
  
  # Generate breadcrumbs for the form builder show page
  def form_builder_show_breadcrumbs(campaign, form_builder)
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: campaign.name, path: campaign_path(campaign) },
          { title: "Form Builders", path: campaign_form_builders_path(campaign) },
          { title: form_builder.name, active: true }
        ]
      }
    end
  end
  
  # Generate breadcrumbs for the form builder edit page
  def form_builder_edit_breadcrumbs(campaign, form_builder)
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: campaign.name, path: campaign_path(campaign) },
          { title: "Form Builders", path: campaign_form_builders_path(campaign) },
          { title: form_builder.name, path: campaign_form_builder_path(campaign, form_builder) },
          { title: "Edit", active: true }
        ]
      }
    end
  end
  
  # Generate breadcrumbs for the form builder new page
  def form_builder_new_breadcrumbs(campaign)
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: campaign.name, path: campaign_path(campaign) },
          { title: "Form Builders", path: campaign_form_builders_path(campaign) },
          { title: "New", active: true }
        ]
      }
    end
  end
  
  # Generate breadcrumbs for the embed codes page
  def form_builder_embed_codes_breadcrumbs(campaign, form_builder)
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: campaign.name, path: campaign_path(campaign) },
          { title: "Form Builders", path: campaign_form_builders_path(campaign) },
          { title: form_builder.name, path: campaign_form_builder_path(campaign, form_builder) },
          { title: "Embed Codes", active: true }
        ]
      }
    end
  end
  
  # Generate breadcrumbs for the form builder element new page
  def form_builder_element_new_breadcrumbs(campaign, form_builder)
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: campaign.name, path: campaign_path(campaign) },
          { title: "Form Builders", path: campaign_form_builders_path(campaign) },
          { title: form_builder.name, path: campaign_form_builder_path(campaign, form_builder) },
          { title: "Add Element", active: true }
        ]
      }
    end
  end
  
  # Generate breadcrumbs for the form builder element edit page
  def form_builder_element_edit_breadcrumbs(campaign, form_builder, element)
    content_for :breadcrumbs do
      render partial: "shared/breadcrumbs", locals: {
        breadcrumbs: [
          { title: "Home", path: root_path },
          { title: "Campaigns", path: campaigns_path },
          { title: campaign.name, path: campaign_path(campaign) },
          { title: "Form Builders", path: campaign_form_builders_path(campaign) },
          { title: form_builder.name, path: campaign_form_builder_path(campaign, form_builder) },
          { title: "Edit Element", active: true }
        ]
      }
    end
  end
end