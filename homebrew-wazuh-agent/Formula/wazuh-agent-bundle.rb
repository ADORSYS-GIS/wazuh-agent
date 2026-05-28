# frozen_string_literal: true

require_relative "wazuh_agent_bundle_shared"

# Homebrew formula for wazuh-agent-bundle
# Installs the Wazuh agent with ADORSYS-GIS security plugins (no IDS engine).
class WazuhAgentBundle < Formula
  include WazuhAgentBundleShared

  desc "Bundled Wazuh agent with ADORSYS-GIS security plugins"
  homepage "https://github.com/ADORSYS-GIS/wazuh-agent"
  url "https://github.com/ADORSYS-GIS/wazuh-agent.git",
      tag:      "v1.8.0",
      revision: "HEAD"
  license "MIT"

  depends_on "wazuh-agent"
  depends_on "wazuh-cert-oauth2-client"
  depends_on "wazuh-agent-status"
  depends_on "wazuh-yara"

  test do
    assert_predicate "/Library/Ossec/active-response/bin/alert-usb-hid.sh", :exist?
    assert_predicate "/Library/Ossec/version.txt", :exist?
  end
end
