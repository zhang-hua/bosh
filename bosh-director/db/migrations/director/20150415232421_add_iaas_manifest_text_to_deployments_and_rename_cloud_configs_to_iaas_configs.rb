Sequel.migration do
  change do
    rename_table :cloud_configs, :iaas_configs
    alter_table :deployments do
      # drop_foreign_key :cloud_config_id
      add_column :iaas_manifest_text, :text
      drop_constraint :fk_deployments_cloud_config_id
      drop_column :cloud_config_id
      add_foreign_key :iaas_config_id, :iaas_configs
    end
  end
end
