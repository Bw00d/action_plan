# :nodoc:
module ApplicationHelper
  # Returns the current layout name. Allows asserting the rendered layout name
  # in our feature specs as an alternative to the deprecated #render_template
  # matcher.
  def layout_name
    # In Rails 6, _layout returns the layout name directly as a string
    layout = controller.send(:_layout, self, [])
    # If it's already a string, just return it
    layout.is_a?(String) ? layout : layout.virtual_path.split('/').last
  end

  # Select the appropriate Boostrap class for Rails's flash messages
  def bootstrap_class_for(flash_type)
    case flash_type
    when 'success'
      'alert-success'   # Green
    when 'error'
      'alert-danger'    # Red
    when 'alert'
      'alert-warning'   # Yellow
    else
      'alert-info'      # Blue
    end
  end

  # Display model validation errors in form templates
  def display_validation_errors(object)
    return '' if object.errors.empty?

    header = I18n.t('activerecord.errors.template.header',
                    count: object.errors.count)
    msgs = object.errors.full_messages.map { |msg| content_tag(:li, msg) }.join

    html = <<-HTML
      <div class="alert alert-danger alert-dismissable" role="alert">
        <button type="button" class="close" data-dismiss="alert">
          <span aria-hidden="true">&times;</span><span class="sr-only">Close</span>
        </button>
        <h4>
          #{header}
        </h4>
        <ul>#{msgs}</ul>
      </div>
    HTML

    html.html_safe
  end

  def current_plan
    if @incident.plans
      @incident.plans.last
    end
  end

  def image_link_to(image_path, url, image_tag_options = { }, link_to_options = { })
  link_to url, link_to_options do
    image_tag image_path, image_tag_options
  end
end

  def pdf_image_url(image)
    if image.attached?
      rails_blob_url(image, host: Rails.application.routes.default_url_options[:host])
    end
  end

  module ActionView  
    class Base  
      def format_date(rec)  
          rec.strftime('%m/%d/%Y')  
      end  
    end  
  end
end
