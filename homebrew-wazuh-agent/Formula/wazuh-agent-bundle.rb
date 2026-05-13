# frozen_string_literal: true

# Homebrew formula for wazuh-agent-bundle
# This formula installs the Wazuh agent with ADORSYS-GIS security plugins

class WazuhAgentBundle < Formula
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

  def install
    # Install USB DLP Active Response scripts
    (prefix/"active-response").mkpath
    cp "files/active-response/disable-usb-storage-macos.sh", prefix/"active-response/"
    cp "files/active-response/alert-usb-hid.sh", prefix/"active-response/"

    # Set correct permissions
    chmod 0750, prefix/"active-response/disable-usb-storage-macos.sh"
    chmod 0750, prefix/"active-response/alert-usb-hid.sh"

    # Write version file
    (prefix/"version.txt").write(version.to_s)
  end

  def post_install
    # Copy scripts to Ossec active-response directory
    ossec_ar_dir = "/Library/Ossec/active-response/bin"
    system "mkdir", "-p", ossec_ar_dir if !Dir.exist?(ossec_ar_dir)
    
    system "cp", prefix/"active-response/disable-usb-storage-macos.sh", ossec_ar_dir + "/"
    system "cp", prefix/"active-response/alert-usb-hid.sh", ossec_ar_dir + "/"
    
    # Set ownership
    system "chown", "root:wheel", ossec_ar_dir + "/disable-usb-storage-macos.sh"
    system "chown", "root:wheel", ossec_ar_dir + "/alert-usb-hid.sh"
    
    # Copy version file to Ossec directory
    system "cp", prefix/"version.txt", "/Library/Ossec/version.txt"
  end

  test do
    assert_match "wazuh-agent-bundle", shell_output("#{bin}/wazuh-agent --version 2>&1", 1)
  end
end
