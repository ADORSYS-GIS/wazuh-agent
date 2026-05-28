# frozen_string_literal: true

require_relative "wazuh_agent_bundle_shared"

# Homebrew formula for wazuh-agent-bundle-snort
# Installs the Wazuh agent with ADORSYS-GIS security plugins and Snort IDS.
class WazuhAgentBundleSnort < Formula
  include WazuhAgentBundleShared

  desc "Bundled Wazuh agent with ADORSYS-GIS security plugins and Snort IDS"
  homepage "https://github.com/ADORSYS-GIS/wazuh-agent"
  url "https://github.com/ADORSYS-GIS/wazuh-agent.git",
      tag:      "v1.8.0",
      revision: "HEAD"
  license "MIT"

  depends_on "wazuh-agent"
  depends_on "wazuh-cert-oauth2-client"
  depends_on "wazuh-agent-status"
  depends_on "wazuh-yara"
  depends_on "wazuh-snort"

  test do
    assert_predicate "/Library/Ossec/active-response/bin/alert-usb-hid.sh", :exist?
    assert_predicate "/Library/Ossec/version.txt", :exist?
  end
end
