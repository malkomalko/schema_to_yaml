require 'yaml'

class MyRxScaffoldGenerator < Rails::Generator::Base
  def extract_attrs(line, attrs)
    attrs.each do |key,value|
      if value.class == Array
        line << " #{key}:#{value.join(',')}"
      else
        line << " #{key}:#{value}"
      end    
    end
    line
  end
  
  def manifest
    record do |m|
      models = YAML.load(File.open(File.join(RAILS_ROOT, 'db/model.yml'), 'r'))
      models.each do |model|
        line = ""
        attrs = model[1]
        if attrs.class == Array
          attrs.each do |elm|
            line = extract_attrs(line, elm)
          end
        else
          line = extract_attrs(line, attrs)
        end
        line = model[0].camelcase + " " + line
        
        if ARGV.size > 0
          ARGV.each do |arg|
            if model[0].camelcase == arg
              puts 'running: the_magic_sauce for: ' + line
              Rails::Generator::Scripts::Generate.new.run(["the_magic_sauce"] + line.split, 
                :flex_only => ARGV.include?('flex_only'),
                :flex_view_only => ARGV.include?('flex_view'),
                :rails_only => ARGV.include?('rails_only')
                )
              puts 'done ...'
              sleep 1
            end
          end
        else
          puts 'running: the_magic_sauce ' + line
          Rails::Generator::Scripts::Generate.new.run(["the_magic_sauce"] + line.split, 
            :flex_only => ARGV.include?('flex_only'),
            :flex_view_only => ARGV.include?('flex_view'),
            :rails_only => ARGV.include?('rails_only')
            )
          puts 'done ...'
          sleep 1
        end
      end
    end
  end

  protected
  def banner
    "Usage: #{$0} #{spec.name}" 
  end
end