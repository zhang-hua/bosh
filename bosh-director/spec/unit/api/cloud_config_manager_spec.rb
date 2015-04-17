require 'spec_helper'

describe Bosh::Director::Api::CloudConfigManager do
  describe "#update" do
    it "saves the cloud config" do
      manager = Bosh::Director::Api::CloudConfigManager.new
      iaas_config_yaml = Psych.dump ManifestHelper.default_iaas_manifest
      expect {
        manager.update(iaas_config_yaml)
      }.to change(Bosh::Director::Models::IaasConfig, :count).from(0).to(1)

      iaas_config = Bosh::Director::Models::IaasConfig.first
      expect(iaas_config.created_at).to_not be_nil
      expect(iaas_config.properties).to eq(iaas_config_yaml)
    end
  end

  describe "#list" do
    it "returns the specified number of cloud configs (most recent first)" do
      days = 24*60*60

      oldest_iaas_config = Bosh::Director::Models::IaasConfig.new(
        properties: "config_from_time_immortal",
        created_at: Time.now - 3*days,
      ).save
      older_iaas_config = Bosh::Director::Models::IaasConfig.new(
        properties: "config_from_last_year",
        created_at: Time.now - 2*days,
      ).save
      newer_iaas_config = Bosh::Director::Models::IaasConfig.new(
        properties: "---\nsuper_shiny: new_config",
        created_at: Time.now - 1*days,
      ).save

      manager = Bosh::Director::Api::CloudConfigManager.new

      iaas_configs = manager.list(2)

      expect(iaas_configs.count).to eq(2)
      expect(iaas_configs[0]).to eq(newer_iaas_config)
      expect(iaas_configs[1]).to eq(older_iaas_config)
    end
  end

  describe "#latest" do
    it "returns the latest" do
      days = 24*60*60

      older_iaas_config = Bosh::Director::Models::IaasConfig.new(
        properties: "config_from_last_year",
        created_at: Time.now - 2*days,
      ).save
      newer_iaas_config = Bosh::Director::Models::IaasConfig.new(
        properties: "---\nsuper_shiny: new_config",
        created_at: Time.now - 1*days,
      ).save

      manager = Bosh::Director::Api::CloudConfigManager.new

      iaas_config = manager.latest

      expect(iaas_config).to eq(newer_iaas_config)
    end

    it "returns nil if there are no cloud configs" do
      manager = Bosh::Director::Api::CloudConfigManager.new

      iaas_config = manager.latest

      expect(iaas_config).to be_nil
    end
  end
end
