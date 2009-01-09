module SchemaToYaml
  module Settings
    class Config
      class << self
        def configure
          yield self
        end

        def settings_file
          @settings_file ||= :schema_to_yaml
        end
        attr_writer :settings_file
      end
    end
  end
end