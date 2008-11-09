namespace :db do
  namespace :schema do
    desc "Create model.yml from schema.rb"
    task :to_yaml => :environment do
      SchemaToYaml.schema_to_yaml
    end
  end
end
