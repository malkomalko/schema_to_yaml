module Enumerable
  def dups
    inject({}) {|h,v| h[v]=h[v].to_i+1; h}.reject{|k,v| v==1}.keys
  end
end

module SchemaToYaml

  def self.schema_to_yaml
    table_arr = ActiveRecord::Base.connection.tables - %w(schema_info schema_migrations).map
    schema = []
    
    ####################################################################################
    # setup array for columns you don't want returned into the yaml
    ####################################################################################
    disregarded_columns = %w(id created_at updated_at)
    @array_of_has_manies = []
    @array_of_polymorphics = []
    
    table_arr.each do |table|
      column_arr = ActiveRecord::Base.connection.columns(table)
      column_arr.each do |col|
        col_name = col.name.to_s
        @array_of_has_manies << "#{col_name.gsub('_id','')}_#{table}" if col_name.include?('_id')
      end
    end
    
    table_arr.each do |table|
      belong_tos = []
      has_manies = []
      polymorphics = []
      schema << "#{table.singularize}:\n"
      column_arr = ActiveRecord::Base.connection.columns(table)
      
      column_arr.each do |col|
        columns_check = []
        col_name = col.name.to_s
        disregarded_columns.each {|dc| columns_check << col_name.include?(dc) }

        polymorphics << col_name.gsub('_id','PMCHECK').gsub('_type','PMCHECK')
        schema << " - #{col_name}: #{col.type}\n" unless columns_check.include?(true)

        if col_name == 'parent_id'
          schema << " - tree_model: [#{col_name.gsub('_id','')}]\n"
        else
          belong_tos << col_name.gsub('_id',', ') if col_name.include?('_id')
        end
      end
      
      if polymorphics.dups.size > 0
        schema << " - polymorphic: [#{polymorphics.dups.first.gsub('PMCHECK','')}]\n"
      end
      
      @array_of_has_manies.each do |hm|
        sanity_check = hm.gsub(/^#{table.singularize}_/,'')
        has_manies << hm.gsub(/^#{table.singularize}_/,'') + ', ' if hm =~ /^#{table.singularize}_/ && table_arr.include?(sanity_check)
      end
      
      if belong_tos.size > 0
        last_in_array_fix = belong_tos.last
        last_in_array_fix = last_in_array_fix.gsub(', ','')
        belong_tos.pop
        belong_tos << last_in_array_fix
        schema << " - belongs_to: [#{belong_tos}]\n"
      end
      
      if has_manies.size > 0
        last_in_array_fix = has_manies.last
        last_in_array_fix = last_in_array_fix.gsub(', ','')
        has_manies.pop
        has_manies << last_in_array_fix
        schema << " - has_many: [#{has_manies}]\n"
      end
      
      schema << "\n"
    end
    
    yml_file = File.join(RAILS_ROOT, "db", "model.yml")
    File.open(yml_file, "w") { |f| f << schema.to_s }
    puts "Model.yml created at db/model.yml"
  end
  
end