module ActiveadminPolymorphic
  class FormBuilder < ::ActiveAdmin::FormBuilder
    def polymorphic_has_many(assoc, poly_name, options = {}, &block)
      custom_settings = :new_record, :allow_destroy, :heading, :sortable, :sortable_start, :types, :path_prefix
      builder_options = {new_record: true, path_prefix: :admin}.merge! options.slice  *custom_settings

      options         = {for: assoc      }.merge! options.except *custom_settings
      options[:class] = [options[:class], "polymorphic_has_many_fields"].compact.join(' ')
      sortable_column = builder_options[:sortable]
      sortable_start  = builder_options.fetch(:sortable_start, 0)

      html = "".html_safe
      html << template.capture do
        contents = "".html_safe

        block = polymorphic_form(poly_name, builder_options)

        template.assign('polymorphic_has_many_block' => true)
        contents = without_wrapper { inputs(options, &block) }

        # if builder_options[:new_record]
        #   contents << js_for_polymorphic_has_many(
        #     assoc, poly_name, template, builder_options, options[:class]
        #   )
        # else
        #   contents
        # end
      end

      tag = @already_in_an_inputs_block ? :li : :div
      html = template.content_tag(tag, html, class: "polymorphic_has_many_container #{assoc}", 'data-sortable' => sortable_column, 'data-sortable-start' => sortable_start)
      template.concat(html) if template.output_buffer
      html
    end

    def sections_has_many(assoc, options = {}, &block)
      custom_settings = :new_record, :allow_destroy, :heading, :position, :sortable_start, :types, :path_prefix
      builder_options = {new_record: true, path_prefix: :admin}.merge! options.slice  *custom_settings
      options         = {for: assoc      }.merge! options.except *custom_settings
      options[:class] = [options[:class], "jsonb"].compact.join(' ')

      collection = options[:collection]

      html = "".html_safe
      html << template.capture do
        contents = "".html_safe
        block = sections_form(assoc, builder_options, collection)
        template.assign('sections_has_many_block' => true)
        # contents = without_wrapper { inputs(options, &block) }

        if builder_options[:new_record]
          contents << js_for_section_has_many(
            assoc, template, builder_options, options[:class], collection
          )
        else
          contents
        end

      end
      tag = @already_in_an_inputs_block ? :li : :div
      html = template.content_tag(tag, html, class: "json_container #{assoc}")
      template.concat(html) if template.output_buffer
      html
    end

    protected

    def polymorphic_has_many_actions(has_many_form, builder_options, contents)
      if has_many_form.object.new_record?
        contents << template.content_tag(:li) do
          template.link_to I18n.t('active_admin.has_many_remove'),
            "#", class: 'button polymorphic_has_many_remove'
        end
      elsif builder_options[:allow_destroy]
        contents << has_many_form.input(:_destroy, as: :boolean,
                            wrapper_html: {class: 'polymorphic_has_many_delete'},
                            label: I18n.t('active_admin.has_many_delete'))
      end

      if builder_options[:sortable]
        contents << has_many_form.input(builder_options[:sortable], as: :hidden)

        contents << template.content_tag(:li, class: 'handle') do
          ::ActiveAdmin::Iconic.icon :move_vertical
        end
      end

      contents
    end

    def json_actions(form, builder_options, contents)
      if @object.new_record?
        contents << template.content_tag(:li) do
          template.link_to I18n.t('active_admin.has_many_remove'),
            "#", class: 'button section_has_many_remove'
        end
      elsif builder_options[:allow_destroy]
        contents << form.input(:_destroy, as: :boolean,
                            wrapper_html: {class: 'section_has_many_delete'},
                            label: I18n.t('active_admin.has_many_delete'))
      end

      if builder_options[:sortable]
        contents << form.input(builder_options[:sortable], as: :hidden)

        contents << template.content_tag(:li, class: 'handle') do
          ::ActiveAdmin::Iconic.icon :move_vertical
        end
      end

      contents
    end

    def js_for_polymorphic_has_many(assoc, poly_name, template, builder_options, class_string)
      new_record = builder_options[:new_record]
      assoc_reflection = object.class.reflect_on_association assoc
      assoc_name       = assoc_reflection.klass.model_name
      placeholder      = "NEW_#{assoc_name.to_s.underscore.upcase.gsub(/\//, '_')}_RECORD"

      text = new_record.is_a?(String) ? new_record : I18n.t('active_admin.has_many_new', model: assoc_name.human)
      form_block = polymorphic_form(poly_name, builder_options, true)

      opts = {
        for: [assoc, assoc_reflection.klass.new],
        class: class_string,
        for_options: { child_index: placeholder }
      }

      html = "".html_safe
      html << template.capture do
        inputs_for_nested_attributes opts, &form_block
      end

      template.link_to text, '#', class: "button polymorphic_has_many_add", data: {
        html: CGI.escapeHTML(html).html_safe, placeholder: placeholder
      }
    end

    def js_for_section_has_many(assoc, template, builder_options, class_string, collection)
      new_record = builder_options[:new_record]
      assoc_reflection = object.class.reflect_on_association assoc
      assoc_name       = assoc_reflection.klass.model_name
      placeholder      = "NEW_#{assoc_name.to_s.underscore.upcase.gsub(/\//, '_')}_RECORD"

      text = new_record.is_a?(String) ? new_record : I18n.t('active_admin.has_many_new', model: assoc_name.human)
      form_block = sections_form(assoc, builder_options, collection)

      opts = {
        for: [assoc, assoc_reflection.klass.new],
        class: class_string,
        for_options: { child_index: placeholder }
      }
      html = "".html_safe
      html << template.capture do
        inputs_for_nested_attributes opts, &form_block
      end
      

      template.link_to text, '#', class: "button section_has_many_add", data: {
        html: CGI.escapeHTML(html).html_safe, placeholder: placeholder
      }
    end

    def polymorphic_options(builder_options)
      # add internationalization
      builder_options[:types].each_with_object([]) do |model, options|
        options << [
          model.model_name.human, model,
          {"data-path" => form_new_path(model, builder_options) }
        ]
      end
    end

    def polymorphic_form(poly_name, builder_options, for_js = false)
      proc do |f|
        html = "".html_safe
        html << f.input("#{poly_name}_id", as: :hidden)

        if f.object.send(poly_name).nil?
          html << f.input("#{poly_name}_type", input_html: { class: 'polymorphic_type_select' }, as: :select, collection: polymorphic_options(builder_options))
        else
          html << f.input(
            "#{poly_name}_type", as: :hidden,
            input_html: {"data-path" =>  form_edit_path(f.object.send(poly_name), builder_options) }
          )
        end

        html << polymorphic_has_many_actions(f, builder_options, "".html_safe)

        html
      end
    end

    def sections_form(field_name, builder_options, collection)
      proc do |form|
        html = "".html_safe

        if @object.send(field_name).blank?
          html << form.input("name", input_html: { class: 'section_type_select' }, as: :select, collection: section_options(collection, builder_options))
        else
          @object.send(field_name).to_a.last.last["fields"].each do |field|
            html << form.input("#{@object.send(field_name).first.first.to_i}[fields][#{field.first}][#{field.last.first.first}]", label: field.last.first.first.try(:humanize), input_html: {value: field.last.first.last})
          end
        end

        html << json_actions(form, builder_options, "".html_safe)

        html
      end
    end

    def form_new_path(object, builder_options)
      "/#{builder_options[:path_prefix]}/#{ActiveModel::Naming.plural(object)}/new"
    end

    def form_edit_path(object, builder_options)
      "/#{builder_options[:path_prefix]}/#{ActiveModel::Naming.plural(object)}/#{object.id}/edit"
    end


    def section_options(collection, builder_options)
      collection.each_with_object([]) do |model, options|
        options << [
          model.name, model,
          {"data-path" => section_form_edit_path(model, builder_options) }
        ]
      end
    end

    def jsonbuilder(assoc, options = {}, &block)
      custom_settings = :new_record, :allow_destroy, :heading, :position, :sortable_start, :types, :path_prefix
      builder_options = {new_record: true, path_prefix: :admin}.merge! options.slice  *custom_settings
      options         = {for: assoc      }.merge! options.except *custom_settings
      options[:class] = [options[:class], "jsonb"].compact.join(' ')
      sortable_column = builder_options[:position]
      sortable_start  = builder_options.fetch(:sortable_start, 0)
      types = options[:types]

      html = "".html_safe
      html << template.capture do
        contents = "".html_safe
        block = json_form(assoc, builder_options)
        contents = without_wrapper { inputs(options, &block) }
      end
      tag = :li
      html = template.content_tag(tag, html, class: "json_container #{assoc}", 'data-sortable' => sortable_column, 'data-sortable-start' => sortable_start)
      template.concat(html) if template.output_buffer
      html
    end

    def json_form(field_name, builder_options)
      proc do |form|
        html = "".html_safe

        if @object.send(field_name).nil?
          html << form.input("#{field_name}_type", input_html: { class: 'json_type_select' }, as: :select, collection: json_options(builder_options))
        else
          @object.send(field_name).to_a.last.last.each do |section_array|
            html << form.input("#{@object.send(field_name).to_a.last.first}[#{section_array.first}]", as: :text, label: section_array.first.try(:humanize), input_html: {value: section_array.last})
          end
        end

        html << json_actions(form, builder_options, "".html_safe)

        html
      end
    end

    def json_options(builder_options)
      # add internationalization
      builder_options[:types].each_with_object([]) do |model, options|
        options << [
          model.model_name.human, model,
          {"data-path" => form_new_path(model, builder_options) }
        ]
      end
    end

    def section_form_edit_path(object, builder_options)
      "/#{builder_options[:path_prefix]}/#{ActiveModel::Naming.plural(object)}/#{object.id}/serialized"
    end


  end
end
