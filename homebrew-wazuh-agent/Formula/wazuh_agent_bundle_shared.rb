# frozen_string_literal: true

# Shared install/post_install logic for all wazuh-agent-bundle formula variants.
# Included by wazuh-agent-bundle, wazuh-agent-bundle-snort, and wazuh-agent-bundle-suricata.
module WazuhAgentBundleShared
  OSSEC_AR_DIR = "/Library/Ossec/active-response/bin"

  def install
    (prefix/"active-response").mkpath
    cp "files/active-response/disable-usb-storage-macos.sh", prefix/"active-response/"
    cp "files/active-response/alert-usb-hid.sh", prefix/"active-response/"
    chmod 0750, prefix/"active-response/disable-usb-storage-macos.sh"
    chmod 0750, prefix/"active-response/alert-usb-hid.sh"
    (prefix/"version.txt").write(version.to_s)
  end

  def post_install
    system "mkdir", "-p", OSSEC_AR_DIR unless Dir.exist?(OSSEC_AR_DIR)
    system "cp", prefix/"active-response/disable-usb-storage-macos.sh", "#{OSSEC_AR_DIR}/"
    system "cp", prefix/"active-response/alert-usb-hid.sh", "#{OSSEC_AR_DIR}/"
    system "chown", "root:wheel", "#{OSSEC_AR_DIR}/disable-usb-storage-macos.sh"
    system "chown", "root:wheel", "#{OSSEC_AR_DIR}/alert-usb-hid.sh"
    system "cp", prefix/"version.txt", "/Library/Ossec/version.txt"
  end
end
