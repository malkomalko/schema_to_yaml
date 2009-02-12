module Rails
  module Generator
    class GeneratedAttribute
      attr_accessor :name, :type, :column, :flex_name

      def initialize(name, type)
        @name, @type = name, type.to_sym
        @flex_name = name.camelcase(:lower)
        @column = ActiveRecord::ConnectionAdapters::Column.new(name, nil, @type)
      end

      def field_type
        @field_type ||= case type
        when :integer, :float, :decimal   then :text_field
        when :datetime, :timestamp, :time then :datetime_select
        when :date                        then :date_select
        when :string                      then :text_field
        when :text                        then :text_area
        when :boolean                     then :check_box
        else
          :text_field
        end      
      end

      def default(prefix = '')
        @default = case type
        when :integer                     then 1
        when :float                       then 1.5
        when :decimal                     then "9.99"
        when :datetime, :timestamp, :time then Time.now.to_s(:db)
        when :date                        then Date.today.to_s(:db)
        when :string                      then prefix + name.camelize + "String"
        when :text                        then prefix + name.camelize + "Text"
        when :boolean                     then false
        else
          ""
        end      
      end
      
      def flex_type
        @flex_type = case type
        when :integer                     then 'int'
        when :date, :datetime, :time      then 'Date'
        when :boolean                     then 'Boolean'
        when :float, :decimal             then 'Number'
        else
          'String'
        end
      end

      def flex_default
        @flex_default = case type
        when :integer                 then '0'
        when :date, :datetime, :time  then 'new Date'
        when :boolean                 then 'false'
        when :float, :decimal         then 'new Number'
        else
          "\"\""
        end
      end
    end
    module Commands
      class Create
        Settings = SchemaToYaml::Settings
      end
    end
  end
end

class TheMagicSauceGenerator < Rails::Generator::NamedBase
  Settings = SchemaToYaml::Settings
  include RestfulX::Configuration
  
  attr_reader   :project_name, 
                :flex_project_name, 
                :base_package, 
                :base_folder, 
                :command_controller_name

  attr_reader   :belongs_tos, 
                :has_manies,
                :has_ones,
                :attachment_field,
                :has_many_through,
                :polymorphic,
                :tree_model,
                :layout,
                :ignored_fields
    
  attr_reader   :controller_name,
                :controller_class_path,
                :controller_file_path,
                :controller_class_nesting,
                :controller_class_nesting_depth,
                :controller_class_name,
                :controller_underscore_name,
                :controller_singular_name,
                :controller_plural_name
                                  
  alias_method  :controller_file_name,  :controller_underscore_name
  alias_method  :controller_table_name, :controller_plural_name
      
  def initialize(runtime_args, runtime_options = {})
    super
    @project_name, @flex_project_name, @command_controller_name, @base_package, @base_folder = extract_names
    @controller_name = @name.pluralize

    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, 
      @controller_class_nesting_depth = extract_modules(@controller_name)
    @controller_class_name_without_nesting, @controller_underscore_name, @controller_plural_name = inflect_names(base_name)
    
    @controller_singular_name=base_name.singularize
    if @controller_class_nesting.empty?
      @controller_class_name = @controller_class_name_without_nesting
    else
      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
    end
    extract_relationships
  end
  
  def manifest
    record do |m|
      unless options[:flex_view_only]
        m.template 'model.as.erb',
          File.join("app", "flex", base_folder, "models", "#{@class_name}.as"), 
          :assigns => { :resource_controller_name => "#{file_name.pluralize}" }
          
        m.template "controllers/#{Settings.controller_pattern}.rb.erb", File.join("app/controllers", 
          controller_class_path, "#{controller_file_name}_controller.rb") unless options[:flex_only]
        
        m.template 'model.rb.erb', File.join("app", "models", "#{file_name}.rb") unless options[:flex_only]
      end
        
      if Settings.layouts.enabled == 'true'
        if @layout.size > 0
          m.template "layouts/#{@layout}.erb",
            File.join("app", "flex", base_folder, "components", "generated", "#{@class_name}Box.mxml"), 
            :assigns => { :resource_controller_name => "#{file_name.pluralize}" }
        else
          m.template "layouts/#{Settings.layouts.default}.erb",
            File.join("app", "flex", base_folder, "components", "generated", "#{@class_name}Box.mxml"), 
            :assigns => { :resource_controller_name => "#{file_name.pluralize}" }
        end
      else
        m.template 'component.mxml.erb',
          File.join("app", "flex", base_folder, "components", "generated", "#{@class_name}Box.mxml"), 
          :assigns => { :resource_controller_name => "#{file_name.pluralize}" }
      end
      
      m.dependency 'rx_controller', [name] + @args
    end
  end
  
  protected
  def extract_relationships
    # arrays
    @belongs_tos = []
    @has_ones = []
    @has_manies = []
    @attachment_field = []
    @polymorphic = []
    @tree_model = []
    @layout = []
    @ignored_fields = []
    
    # hashes
    @has_many_through = {}

    @args.each do |arg|
      # arrays
      if arg =~ /^has_one:/
        @has_ones = arg.split(':')[1].split(',')
      elsif arg =~ /^has_many:/
        @has_manies = arg.split(":")[1].split(",")
      elsif arg =~ /^belongs_to:/
        @belongs_tos = arg.split(":")[1].split(',')
      elsif arg =~ /^attachment_field:/
        @attachment_field = arg.split(":")[1].split(',')
      elsif arg =~ /^polymorphic:/
        @polymorphic = arg.split(":")[1].split(',')
      elsif arg =~ /^tree_model:/
        @tree_model = arg.split(":")[1].split(',')
      elsif arg =~ /^layout:/
        @layout = arg.split(":")[1].split(',')
      elsif arg =~ /^ignored_fields:/
        @ignored_fields = arg.split(":")[1].split(',')
      # hashes
      elsif arg =~ /^has_many_through:/
        hmt_arr = arg.split(":")[1].split(',')
        @has_many_through[hmt_arr.first] = hmt_arr.last
      end
    end
    
    # delete special fields from @args ivar
    %w(has_one has_many belongs_to attachment_field has_many_through 
      polymorphic tree_model layout ignored_fields).each do |special_field|
      @args.delete_if { |f| f =~ /^(#{special_field}):/ }
    end
    
    # delete ignored_fields from @args ivar
    @ignored_fields.each do |ignored|
      @args.delete_if { |f| f =~ /^(#{ignored}):/ }
    end
    
  end
  
  def add_options!(opt)
    opt.separator ''
    opt.separator 'Options:'
    opt.on("-f", "--flex-only", "scaffold flex code only", 
      "Default: false") { |v| options[:flex_only] = v}
    opt.on("-r", "--rails-only", "scaffold rails code only", 
      "Default: false") { |v| options[:rails_only] = v}
    opt.on("-fv", "--flex_view_only", "scaffold flex generated component only", 
      "Default: false") { |v| options[:flex_view_only] = v}
  end
end