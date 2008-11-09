module SchemaToYaml

  def self.schema_to_yaml
    table_arr = ActiveRecord::Base.connection.tables - %w(schema_info schema_migrations).map
    schema = []
    
    table_arr.each do |table|
      schema << "#{table.singularize}:\n"
      column_arr = ActiveRecord::Base.connection.columns(table) 
      column_arr.each do |col|
        col_name = col.name.to_s
        schema << " - #{col.name}: #{col.type}\n" unless col_name.include?('id') || col_name.include?('created_at') || col_name.include?('updated_at')
      end
      schema << "\n"
    end
    
    yml_file = File.join(RAILS_ROOT, "db", "model.yml")
    File.open(yml_file, "w") { |f| f << schema.to_s }
    puts "Model.yml created at db/model.yml"
  end
  
end