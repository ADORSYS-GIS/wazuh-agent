# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.9.0](https://github.com/ADORSYS-GIS/wazuh-agent/compare/v1.8.0...v1.9.0) (2026-02-20)


### Features

* add BurntToastModule Installation ([58bab5c](https://github.com/ADORSYS-GIS/wazuh-agent/commit/58bab5cefdb98e7f31fe1e76ce57274271214e44))
* add dependency script to setup agent script ([ace8444](https://github.com/ADORSYS-GIS/wazuh-agent/commit/ace8444b5aff3e80763c07f116f3bdfd3c4c1494))
* add uninstall functions for Snort and Suricata, update default NIDS to Suricata ([e3fd5e8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/e3fd5e862d6d6b2aa940ef5a23bcfdfd6255cdbf))
* add uninstall scripts ([40bd168](https://github.com/ADORSYS-GIS/wazuh-agent/commit/40bd168a6b2b9147589bf7d5900c96a46eece072))
* add uninstall scripts ([86b9ae9](https://github.com/ADORSYS-GIS/wazuh-agent/commit/86b9ae97a68f7081ea368cfd9e9175f4242abb7e))
* add USB DLP Active Response scripts ([08767bc](https://github.com/ADORSYS-GIS/wazuh-agent/commit/08767bc9967f3e0d799224f2aeebc7d50aa5c706))
* add verified bootstrap installer with SHA256 checksum verification ([c345771](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c345771e8d1a5edc8ed232f82f37c2448fa95459))
* add version compatibility matrix and automatic changelog generation ([d9ab49f](https://github.com/ADORSYS-GIS/wazuh-agent/commit/d9ab49fa1ae9b98deb61e7b7a3ebbb75ee9c7e76))
* add wazuh agent uninstall script ([3899dec](https://github.com/ADORSYS-GIS/wazuh-agent/commit/3899dec0d7c75cdc6284e91fb480da6015a11297))
* added functionality for update script to write to active-responses.log ([cbbe76d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/cbbe76d57bcc0e833f652fefe2401e702b74cd08))
* **chore:** add uninstall script ([1535d83](https://github.com/ADORSYS-GIS/wazuh-agent/commit/1535d839333ef429107f19e3374429b9ff02ca0c))
* **chore:** add upgrade script creation in windows agent setup ([e3a2b3f](https://github.com/ADORSYS-GIS/wazuh-agent/commit/e3a2b3f09a6c29125ec48407633d180954ee2b9a))
* **chore:** add validation of installation ([bc53635](https://github.com/ADORSYS-GIS/wazuh-agent/commit/bc53635db07643a5ee7eb3a8796ae52bb3fa5711))
* **chore:** change the path of the update script ([3e20e9c](https://github.com/ADORSYS-GIS/wazuh-agent/commit/3e20e9c0c5231de6b2609d8c3c4ba6d170811a44))
* **chore:** remove un-necessary sudo ([1b631d8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/1b631d860b067006e03222e46f465b124fc7f4b6))
* **chore:** update install.sh file to use a single wazuh manager address ([831b3b1](https://github.com/ADORSYS-GIS/wazuh-agent/commit/831b3b1abf573647f487d5aa1d866f159f689bdb))
* **chore:** WAZUH_AGENT_VERSION -&gt; 4.9.2 ([b361af1](https://github.com/ADORSYS-GIS/wazuh-agent/commit/b361af1b62ce2207b6f08160c75daa40a035d296))
* **chore:** WAZUH_AGENT_VERSION -&gt; 4.9.2-1 ([469f337](https://github.com/ADORSYS-GIS/wazuh-agent/commit/469f3378a22deb7d5dcd93e4012e465cfdeacdfa))
* **chore:** WAZUH_AGENT_VERSION -&gt; 4.9.2-2 ([24a93f7](https://github.com/ADORSYS-GIS/wazuh-agent/commit/24a93f79cf5b26260885486c544b7968567056ef))
* enhance CI/CD pipeline with Unix and Windows test jobs and release process ([25e58a4](https://github.com/ADORSYS-GIS/wazuh-agent/commit/25e58a4c030fd6bb6539971b80b947815a020edd))
* global variables and remove temp msi executable file ([e178e59](https://github.com/ADORSYS-GIS/wazuh-agent/commit/e178e59efe6174dd60d54d350d54e2e949affcdb))
* improve nids selection, validation, docs, and ci for agent scripts ([d78e98a](https://github.com/ADORSYS-GIS/wazuh-agent/commit/d78e98a18f38de35ebb5e680e436d71e2654e1f1))
* install Nuget package provider before installing the BurntToast module ([be2770d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/be2770ddea6002fd69d82cb86c3d111ac1e8e3d7))
* integrate pre update notification from wazuh agent status ([1a631ce](https://github.com/ADORSYS-GIS/wazuh-agent/commit/1a631ce43cc10698edf647528f6ef6b11e09a177))
* integrate Renovate for automatic dependency updates ([fb81930](https://github.com/ADORSYS-GIS/wazuh-agent/commit/fb81930964fbde0acd12d9f77b49b99d2292db98))
* **linux agent:** added automatic config conflict resolution to install script ([2919ff3](https://github.com/ADORSYS-GIS/wazuh-agent/commit/2919ff356989a8ffc5e4bf6c00df5cd64c7f83a1))
* **linux agent:** added automatic config conflict resolution to install script ([0576232](https://github.com/ADORSYS-GIS/wazuh-agent/commit/057623299f8ec2de59d63a4954086f563c78f773))
* **nids:** integrate suricata installation ([4c8f732](https://github.com/ADORSYS-GIS/wazuh-agent/commit/4c8f7321aa0832f4c0d02754a000ad696f6c0683))
* ota update ([66f1a0c](https://github.com/ADORSYS-GIS/wazuh-agent/commit/66f1a0c647354a72d677fc53d70604ef704ddd69))
* **release:** add pull request trigger and add job steps to test install and setup-agent scripts on linux/macos in release workflow ([f36d57e](https://github.com/ADORSYS-GIS/wazuh-agent/commit/f36d57e57538a0779c56872b0919113346a02687))
* remove Wazuh Service ([c02529d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c02529dc667d6d44261ee2d588c19d82d2e3fefc))
* **scripts:** enhance upgrade script with global variable handling a… ([8eb9d38](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8eb9d38d51815226695d1dcc3e6f1f1f0a33e7bd))
* **scripts:** enhance upgrade script with global variable handling and notifications ([36f08a8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/36f08a838898a946bb6c88f54a6e85ef50a35ded))
* set PSGallery to trusted ([08f6518](https://github.com/ADORSYS-GIS/wazuh-agent/commit/08f6518aee3531add1c9c30a421af5e027967fae))
* **setup-agent:** add installation of suricata and enhance setup-agent.sh with improved configuration and help messaging ([03a7d43](https://github.com/ADORSYS-GIS/wazuh-agent/commit/03a7d433edcfbcefedc5a36f10b5b0be2a0090b8))
* testing utility for load testing ([b8d1ee8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/b8d1ee86974702788dc506af4b4bd39559fc7247))
* **uninstall-agent:** enhance uninstallation-agent.sh script with configurable IDS options and improved help messaging ([e7f34fd](https://github.com/ADORSYS-GIS/wazuh-agent/commit/e7f34fd74b4e802e59cc1a39500e2cb424447bdf))
* version upgrade -&gt; 4.9.2 ([8248cb4](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8248cb4ddf1c508c0641ad113791bef9b41136d7))
* version upgrade -&gt; 4.9.2 ([6e01015](https://github.com/ADORSYS-GIS/wazuh-agent/commit/6e0101594465fa88cc415406903eec660e686612))
* version.txt -&gt; v1.3.0 ([6cb57fe](https://github.com/ADORSYS-GIS/wazuh-agent/commit/6cb57fe4dfd092d6eeac1dd26111e6b473e6c7ec))
* WAZUH_AGENT_STATUS_VERSION -&gt; v0.3.0 ([1ac6933](https://github.com/ADORSYS-GIS/wazuh-agent/commit/1ac6933281fe238731e46526536348c0d411df24))
* WAZUH_AGENT_STATUS_VERSION -&gt; v0.3.0 ([457fe71](https://github.com/ADORSYS-GIS/wazuh-agent/commit/457fe7148ee4b104ab617602623d93b04bae4760))
* **windows:** add suricata installation on windows and enhance setup and uninstall scripts with improved logging and help functions ([f05c052](https://github.com/ADORSYS-GIS/wazuh-agent/commit/f05c0520d52501d5ee99b1e82e8acfb63e84c10b))


### Bug Fixes

* add colour to log function ([0049738](https://github.com/ADORSYS-GIS/wazuh-agent/commit/00497387e669fdb7e2b6c87d9aca0fb2b23a44b9))
* add correct wazuh agent version ([87e77cc](https://github.com/ADORSYS-GIS/wazuh-agent/commit/87e77ccbc157461b8ba0313b03874de24f28d92a))
* add default value for WAZUH_SURICATA_VERSION in windows setup script ([143060d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/143060de1ca8196e78a3c178244fe6cf1afe65a1))
* add default value for WAZUH_SURICATA_VERSION in wndows setup script ([b2e3650](https://github.com/ADORSYS-GIS/wazuh-agent/commit/b2e3650232e05c41bc6058f1fd0ed5d52bb64c65))
* add OSSEC_LOG_PATH variable and improve logging messages in install script ([2431031](https://github.com/ADORSYS-GIS/wazuh-agent/commit/2431031b3c7a854d144309bad80730576918dd70))
* add successMessage where missing ([c67b6cd](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c67b6cdf8a0598eea7085e3899c716eec50f11bd))
* add version check for installed Wazuh agent in install scripts ([db4c072](https://github.com/ADORSYS-GIS/wazuh-agent/commit/db4c072e91fbefc6e3f63ddf17e9c964fe140f60))
* address P0 security and CI gaps ([81804fb](https://github.com/ADORSYS-GIS/wazuh-agent/commit/81804fb59144c9c31cef243890b9d8921172a53f))
* address P0 security and CI gaps ([bedbd42](https://github.com/ADORSYS-GIS/wazuh-agent/commit/bedbd42435090652e6d258feeeb567c878fe01e5))
* allow install.ps1 to accept passed in variables ([4365745](https://github.com/ADORSYS-GIS/wazuh-agent/commit/4365745b120f68f9750b7afed94c863fcde15b54))
* burntToast module needs to be imported in order to be used ([2fdad54](https://github.com/ADORSYS-GIS/wazuh-agent/commit/2fdad5444eb6e30fb26cddfb15aceebd29195bf8))
* Change associative array to indexed array to work for older versions of bash found on macOS ([a771ee0](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a771ee0ae70e6c72cf3d3bd47cbc626da34ebbbb))
* change param placement to fix strict mode errors ([a345b3f](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a345b3fcfdfd3d93679df8c5587ee4412b0ff6e1))
* change url for Agent Status to issue branch ([c286bf5](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c286bf53828d69c59413ea41d5a94d3a987c3a17))
* change warnmessage to infomessage to match other functions ([402e946](https://github.com/ADORSYS-GIS/wazuh-agent/commit/402e946eec5af5279bb6d1fb0e80b70f0007c3d1))
* **chore:** change wazuh manager address to test-cluster.wazuh.adorsys.team ([a3db6b2](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a3db6b2ebb33c13217444de19781419bcc8ac0af))
* **chore:** changed if function to check jq, curl and gnu-sed exists, if not it installs the packages ([167d540](https://github.com/ADORSYS-GIS/wazuh-agent/commit/167d5407ad426343132909d43826ad69bf325f68))
* **chore:** check if curl or jq or gnu-sed command does not exist ([0782c74](https://github.com/ADORSYS-GIS/wazuh-agent/commit/0782c744b3ac0c4aad5e060f4a1bb341a1b421c5))
* **chore:** improve logs ([eb56955](https://github.com/ADORSYS-GIS/wazuh-agent/commit/eb569552edcf2e00029719cf287b0e4a3df15fad))
* **chore:** improve maybe_sudo in uninstall script ([db725e0](https://github.com/ADORSYS-GIS/wazuh-agent/commit/db725e0f1ee139c40c4ca831c94ae10539393fe6))
* **chore:** make remove_user_group function usable on macos and linux ([78944e6](https://github.com/ADORSYS-GIS/wazuh-agent/commit/78944e674cba61aa2550a17bfdf29a670afe80c4))
* **chore:** remove unecessary premature exits in agent installation v… ([7e17b57](https://github.com/ADORSYS-GIS/wazuh-agent/commit/7e17b5724a3ba15faf1b514b2985f43ae0bdce0e))
* **chore:** remove unecessary premature exits in agent installation validation ([9c7bf2e](https://github.com/ADORSYS-GIS/wazuh-agent/commit/9c7bf2ea050c9ab894786b3bb2c475e39a68dba4))
* **chore:** removed exit after sucess message ([b50296f](https://github.com/ADORSYS-GIS/wazuh-agent/commit/b50296fc763a1b874e332ac7749e7d92f61b227f))
* **chore:** update use of sed ([798e293](https://github.com/ADORSYS-GIS/wazuh-agent/commit/798e293543d268a67c48fbf32ea55c848933c82c))
* configure jsonpath for versions.json and sync to v1.8.0 ([8d676b3](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8d676b3cbb55a1355d68d1aa7cf902a2a3243f65))
* correct message in validation check and ensure validation is always performed after installation ([ffe1e3c](https://github.com/ADORSYS-GIS/wazuh-agent/commit/ffe1e3c30f6b588e2136f2e970712a9ab43bd19f))
* correct typo in installation skip message in install.sh ([6edd4f9](https://github.com/ADORSYS-GIS/wazuh-agent/commit/6edd4f9a9f6fefcaedc6091496d9e0caa205b179))
* correct URL typo in uninstall-agent.sh, reorder variables in setup-agent.ps1, and update help text to use variable values ([c6fbcd8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c6fbcd812b92e080af046952a41a53daadd7dfd0))
* declare agent version before being called in Download Url ([3f9cba3](https://github.com/ADORSYS-GIS/wazuh-agent/commit/3f9cba3ece1c45bc7cd8d6c671ae42edd8c6eb78))
* directory 'Program Files(x86)' --&gt; 'Program Files (x86)' ([078d5fb](https://github.com/ADORSYS-GIS/wazuh-agent/commit/078d5fbeb11c747fd5d80cae14c3c4946b02e35c))
* Directory for agent status image was set to linux instead of windows ([5591b67](https://github.com/ADORSYS-GIS/wazuh-agent/commit/5591b67894810877a887ed5f18ba16449d218629))
* **doc:** update windows enrollment guide command to download setup-agent script and then run it ([0a7ab0b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/0a7ab0beb5768e260c6a54de28f2235676f7344c))
* enhance error handling for enabling and disabling Wazuh repository ([039d782](https://github.com/ADORSYS-GIS/wazuh-agent/commit/039d782c1056ba2af8570dd9906846299446554d))
* ensure Cleanup function is called after installation steps in install.ps1 ([bfa5cf2](https://github.com/ADORSYS-GIS/wazuh-agent/commit/bfa5cf2331bd02bb82a4c0dd843359efdff417f9))
* ensure config, upgrade script creation, agent start, and validation are always executed during installation ([78ea857](https://github.com/ADORSYS-GIS/wazuh-agent/commit/78ea8575cf9743704bc2cba507531a0b532dd8e5))
* environment path for gnu_sed ([a42500a](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a42500a385f34d40441c4b6aba042b243f12d2c2))
* fix conflicts with develop branch ([a8613b4](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a8613b4f373d2719b46e6153277562e153ce446d))
* fix log display issue in OTA script ([53699d0](https://github.com/ADORSYS-GIS/wazuh-agent/commit/53699d00e5e875a9539eb7ef3b2e5c675c394d96))
* fix maybe_sudo issue ([8f03850](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8f03850fcc8bcd814fbff85f1849d0ce30054dea))
* fix paths ([1f8f60b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/1f8f60b7649bcbf2ca48505e66fdf6d66fa24a26))
* fix the temp files cleanup position in the OTA update script on linux/macos ([97a81da](https://github.com/ADORSYS-GIS/wazuh-agent/commit/97a81daafa0a29d9df1cee8ae35fb9608ab50157))
* fix use of maybe_sudo in setup-agent.sh file ([da98aae](https://github.com/ADORSYS-GIS/wazuh-agent/commit/da98aaee3a10d7cbb99c728a8b92f84178f21daf))
* fix use of maybe_sudo in setup-agent.sh file ([786b182](https://github.com/ADORSYS-GIS/wazuh-agent/commit/786b182ab99268a7fd92a68faad122983e107d96))
* fix version.txt download ([2933075](https://github.com/ADORSYS-GIS/wazuh-agent/commit/2933075e83c6b3315ba0bacc48afce1321ad1f8a))
* fix wazuh-logo validation function ([4963dc5](https://github.com/ADORSYS-GIS/wazuh-agent/commit/4963dc5430085915c8932dfb14a85b6e6193b3d9))
* fixed URL for installation script in README.md ([d7db78a](https://github.com/ADORSYS-GIS/wazuh-agent/commit/d7db78a4927c5e457a124437f7b46ed74e194c61))
* give value to ossec config file based on the OS ([15d4f40](https://github.com/ADORSYS-GIS/wazuh-agent/commit/15d4f40138a85a4bb013b19af8294e79d78a8322))
* GnuSed installation was not being called ([d2f4576](https://github.com/ADORSYS-GIS/wazuh-agent/commit/d2f4576f7e0bdbe31a938580deda6f2667ba9e0c))
* images not showing due to whitespace before src direcotry ([aca8b07](https://github.com/ADORSYS-GIS/wazuh-agent/commit/aca8b0707d4da670eda30a9a22cffbbd11f14c71))
* improve how to use maybe_sudo in setup-agent.sh script for OTA update ([ad18984](https://github.com/ADORSYS-GIS/wazuh-agent/commit/ad18984f1bfe276dd8ac4aff074b80f02c31cf76))
* Improve logging for windows install script ([03a3d44](https://github.com/ADORSYS-GIS/wazuh-agent/commit/03a3d44ed54590948389d5f3a26d1be6922ba62a))
* Improve logging on dependency installation script ([fb80800](https://github.com/ADORSYS-GIS/wazuh-agent/commit/fb808008da3b5dd49727ae01585bd80678d56891))
* improve the function to delete manager_address if it exists ([b549660](https://github.com/ADORSYS-GIS/wazuh-agent/commit/b5496608c7ce7ce66b5b27c939f691ac869f789e))
* improve update script ([51c6be1](https://github.com/ADORSYS-GIS/wazuh-agent/commit/51c6be18aa18e53c84e75d13d6d9fb0ba92f5f7a))
* improve version detection and add warnings for unsupported cases ([713bd62](https://github.com/ADORSYS-GIS/wazuh-agent/commit/713bd6256c9596b20e3c6f62bef371c0e802e965))
* indentaions ([d4148c4](https://github.com/ADORSYS-GIS/wazuh-agent/commit/d4148c49ded857ce2cf2098ad829943d46c1778a))
* install burnttoast module on LocalMachine Scope ([c973a2d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c973a2d9ec4f0d056387b2934ee869d4826c46d9))
* LocalMachine Scope does not exist, use AllUsers ([c50a880](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c50a88036fa2c4214097fbc8fd97078c9594c781))
* logging function called incorrectly ([053bed3](https://github.com/ADORSYS-GIS/wazuh-agent/commit/053bed30dbc3a663ae57818c42d15ef81b7ea4ba))
* logging function called incorrectly ([96381f8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/96381f874d1798b5c8366efbad38a0196e193eaf))
* macOS dependencies in dep.sh ([6678f9a](https://github.com/ADORSYS-GIS/wazuh-agent/commit/6678f9aa9b4934dafacd7f4f5d70d9382007ad32))
* macOS dependencies in dep.sh ([b9f65ee](https://github.com/ADORSYS-GIS/wazuh-agent/commit/b9f65eeb4cc6ca3c092963fc5345fbdd4aae96fc))
* make script add servec address in ossec.conf ([a000341](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a0003413a6aa395fddcacf9351d7d98652f0fe54))
* make script work in root mode ([491649e](https://github.com/ADORSYS-GIS/wazuh-agent/commit/491649ebed4eed74d63a4f204ee9236b5c2b3ddd))
* make script work in root mode ([8dfa1d7](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8dfa1d742e887fc03424774e13b1dd01a16ded20))
* make script work in root mode ([fde939a](https://github.com/ADORSYS-GIS/wazuh-agent/commit/fde939a4521613cb84801fb39925041b0f4d0c3c))
* make script work in root mode ([e715cb3](https://github.com/ADORSYS-GIS/wazuh-agent/commit/e715cb3a96fa3a52691b4c36a0fe15703b4f8367))
* make script work in root mode ([2020a4b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/2020a4b8301478e487d38ce8dc1fe4edb345d7db))
* pass WAZUH_MANAGER environment variable to install-wazuh-agent-status script ([99149e8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/99149e8461fe1975a04a03178cfcb4b09615ffb0))
* **release:** correct ShellCheck path and pattern configuration in workflow ([f73e94a](https://github.com/ADORSYS-GIS/wazuh-agent/commit/f73e94a32bd2dd7cc8462a03fd20971a8fda2505))
* remove argument list ([b582c25](https://github.com/ADORSYS-GIS/wazuh-agent/commit/b582c25749a6ed52948896ee073e144564efb336))
* remove calling gnu-sed function twice ([78dd7c0](https://github.com/ADORSYS-GIS/wazuh-agent/commit/78dd7c06f89847aa9f7c1ef13d1755835cc8593a))
* remove check for curl and jq early in the script ([1ee88de](https://github.com/ADORSYS-GIS/wazuh-agent/commit/1ee88de460a4430d2d8a82cd8798f17e61d8d48f))
* remove commented out command ([8b51c46](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8b51c466badeeed82d00d4652bd78a5911fab404))
* remove Create-Upgrade-Script function and update WAZUH_AGENT_STATUS_VERSION to 0.3.3 in setup-agent script ([ffcbf7f](https://github.com/ADORSYS-GIS/wazuh-agent/commit/ffcbf7f82c7ac9b5a3d77615ad5d87848954db23))
* remove creation of adorsys-update script and update WAZUH_AGENT_STATUS_VERSION to 0.3.3 in setup-agent script ([e3669f5](https://github.com/ADORSYS-GIS/wazuh-agent/commit/e3669f57c86dcbe7aed1cf4adc978ee376ff35ec))
* Remove ErrorAction Stop and Wait from stop-service ([a6dd608](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a6dd608ecbf35ef9e5f4847a731f8065e4e1f9ee))
* remove python install script not needed ([220b96b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/220b96bd61ad301cb67d2deb8b8b5387880b0495))
* remove scope from install-module ([7ae6f2f](https://github.com/ADORSYS-GIS/wazuh-agent/commit/7ae6f2f827b42127be6ac0243c56ea13eb56d858))
* remove tags in OTA scripts ([fb77e2e](https://github.com/ADORSYS-GIS/wazuh-agent/commit/fb77e2e17a743f6a556a5c04827c41d66a129116))
* remove tags in OTA scripts ([8cb4956](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8cb4956ca445dd6626b9fc2ad52685243921b879))
* remove temp files ([b4ecf50](https://github.com/ADORSYS-GIS/wazuh-agent/commit/b4ecf5082680615cd451aa5e7346119f08a43b87))
* remove valhallaAPI installation not needed ([7f28404](https://github.com/ADORSYS-GIS/wazuh-agent/commit/7f28404ce061647f7f327b41e8c04f0f9b8c3ef1))
* Removed paramaters that don't work ([a5f4d3b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a5f4d3b8b66123585089ef351af3c1a8fb4b62ea))
* run agent-status install with root privileges ([da051be](https://github.com/ADORSYS-GIS/wazuh-agent/commit/da051be5aa798e9c5486f0610ef1bd5bf122065a))
* run agent-status install with root privileges ([09482fa](https://github.com/ADORSYS-GIS/wazuh-agent/commit/09482fa254ec6fbf2a0cf4e0862b6e38db56f51f))
* sed version check  for macOS ([4a14a26](https://github.com/ADORSYS-GIS/wazuh-agent/commit/4a14a26ed504ae29ba46e13c3093fafda26c5d88))
* **setup-agent:** remove sudo usage in Suricata, Snort, and Trivy installation steps with to avoid conflic with homebrew ([af576d7](https://github.com/ADORSYS-GIS/wazuh-agent/commit/af576d7061287c651d285f007a6a4bb4029888c9))
* sync version to v1.7.2 and fix release workflow ([6bacbef](https://github.com/ADORSYS-GIS/wazuh-agent/commit/6bacbef4454107284edb81838bdbfe33042ce204))
* sync version to v1.8.0 ([2cab884](https://github.com/ADORSYS-GIS/wazuh-agent/commit/2cab8841e6c79419d37f2fabb9d49a326e9b19bd))
* Syntax Error line 63 Windows enrollment readme ([cbdac5c](https://github.com/ADORSYS-GIS/wazuh-agent/commit/cbdac5cd5b23632d00f142cb1c7d2bc94b4699b8))
* TempFile not being called correctly ([8a0f004](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8a0f00438c07b0bc8ae7635566b762c1d968a107))
* uninstall agent script template complete ([7c79149](https://github.com/ADORSYS-GIS/wazuh-agent/commit/7c791494a7b889c9b60d59614751338b9e421817))
* **uninstall:** update script to completely purge after wazuh agent uninstallation on linux ([33c4918](https://github.com/ADORSYS-GIS/wazuh-agent/commit/33c4918d9f0a645309bb02797fd5901d85c64f98))
* update default version values for YARA, Snort, and Suricata in setup and uninstall scripts ([388b99d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/388b99d798914cfc8e6ae1b41c18198a68b92fc4))
* update default version values for YARA, Snort, and Suricata in setup and uninstall scripts ([00c1803](https://github.com/ADORSYS-GIS/wazuh-agent/commit/00c1803e0fd5653bd6fb1387acf07691437bfc17))
* update install script URL for Wazuh agent status to use user-main branch ([6a4e0c8](https://github.com/ADORSYS-GIS/wazuh-agent/commit/6a4e0c8448cf11bf0dddc42efac80c49a5cf0eb1))
* update install script URL for Wazuh agent status to use version tag ([8d9e06e](https://github.com/ADORSYS-GIS/wazuh-agent/commit/8d9e06edc8a7e549a76300bbebd91df70767575b))
* update install script urls ([f524acc](https://github.com/ADORSYS-GIS/wazuh-agent/commit/f524acca49a2f7d64ddfd0058fb6063fd3c09e42))
* update installer script URLs to point to the correct branch for Wazuh agent installation ([891c059](https://github.com/ADORSYS-GIS/wazuh-agent/commit/891c059558dc5c0b11d331e72f6cb51a8dfe124b))
* update ossec paths ([a76d157](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a76d1570ca90755b285082dd54521f5d48010bde))
* update position on trap cleanup ([4499a44](https://github.com/ADORSYS-GIS/wazuh-agent/commit/4499a44cee980233e746f55c44a0625bfe32516e))
* update setup and uninstall script commands for Linux and MacOS enrollment guides ([df5c03b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/df5c03b08a0d1de8db4a82c92905974e00e9d9e1))
* update uninstall script to use 'apt remove --purge' for Wazuh agent removal ([820dd2b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/820dd2beedde9d80a5c35cd3a56ecf24a2ff9996))
* update uninstall script to use 'apt-get purge' for Wazuh agent removal ([0f5d27d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/0f5d27da07fd3f10c3ad3422395641bdc871b967))
* update url for agent status install script ([bc13a6c](https://github.com/ADORSYS-GIS/wazuh-agent/commit/bc13a6c1cb700692dd20e8ffaf6ba6bc7b8c51ca))
* update urls for scripts to tags ([a42d2e4](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a42d2e4f16d5cc35feff822f11d88b3d4b51f840))
* update urls to develop branches ([cb79fb2](https://github.com/ADORSYS-GIS/wazuh-agent/commit/cb79fb2cc8c758ca3abd3df4061586569f5b390e))
* update urls to main branch ([deb3b7d](https://github.com/ADORSYS-GIS/wazuh-agent/commit/deb3b7d8ceb2adb531853dabb3899fd1c332d0b0))
* update urls to use tags of each script ([b128ae3](https://github.com/ADORSYS-GIS/wazuh-agent/commit/b128ae3f09ade8e3a949295d798bfdd5fa35488c))
* update Wazuh Agent version to 4.12.0-1 in installation and uninstallation scripts ([19b056b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/19b056b146a06d9f0c8f957020c34d40468eee28))
* update wazuh manager address ([5e997d9](https://github.com/ADORSYS-GIS/wazuh-agent/commit/5e997d907a47fffadcbc41b5626935fcab579937))
* update WAZUH_AGENT_STATUS_VERSION to 0.3.3 in uninstall scripts ([a431202](https://github.com/ADORSYS-GIS/wazuh-agent/commit/a4312024649e3aa9801205b7117474dd3967740b))
* update WAZUH_YARA_VERSION to 0.3.4 in setup scripts ([e0eebc1](https://github.com/ADORSYS-GIS/wazuh-agent/commit/e0eebc1ed47974ad0d5431e3e9e983f81efb8965))
* update WAZUH_YARA_VERSION to 0.3.5 in setup and uninstall scripts ([1e972ce](https://github.com/ADORSYS-GIS/wazuh-agent/commit/1e972ce75e73ff2194d14f2d258c89ddc632770e))
* update windows enrollment doc ([73c7c30](https://github.com/ADORSYS-GIS/wazuh-agent/commit/73c7c30c4614962a2308efe114ba0caa27d30a58))
* use correct logging function ([e2bd2ae](https://github.com/ADORSYS-GIS/wazuh-agent/commit/e2bd2ae26b134ba4ae7ddd1ddf0b9a4517325518))
* use PAT for release-please to bypass org restrictions ([c7d449c](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c7d449c77e215923393291dc34432f6ab7c0b534))
* using write-host to print ([7218d30](https://github.com/ADORSYS-GIS/wazuh-agent/commit/7218d30e002c25b6198a998a7a47bef4648f41a2))
* version check for installed Wazuh agent in install scripts ([3347365](https://github.com/ADORSYS-GIS/wazuh-agent/commit/334736585c232e3c683eed689bcc945ddf304433))
* wazuh agent repo url spelling error ([5b8bdbb](https://github.com/ADORSYS-GIS/wazuh-agent/commit/5b8bdbbf20ba581d41891450611bd2ed58a1a56d))
* wazuh snort script url ([2327125](https://github.com/ADORSYS-GIS/wazuh-agent/commit/23271250b90c8b5b47d85cacdb46c67a05cfb93a))
* wazuh_agent_version variable name ([5378986](https://github.com/ADORSYS-GIS/wazuh-agent/commit/5378986f3f38bc71f6d8f17cf5b9accb924be597))
* wazuh_manager variable name ([c2cc670](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c2cc670a2ac155fc360cd94a790e511219248c6c))
* whitespace error on image src directory ([c50131b](https://github.com/ADORSYS-GIS/wazuh-agent/commit/c50131b3955fa6fc69002c635c26bfd9c386e105))
* YaraURL was incorrect ([7bbce6a](https://github.com/ADORSYS-GIS/wazuh-agent/commit/7bbce6a10392ca909a771ce74828aefdbd71dc8a))


### Documentation

* add installation runbook with step-by-step instructions ([6ddd919](https://github.com/ADORSYS-GIS/wazuh-agent/commit/6ddd919ea1342a2b2866d5416ba63f719e294a67))

## [Unreleased]

### Added
- Verified bootstrap installer with SHA256 checksum verification
- Installation runbook documentation
- Version compatibility matrix (`versions.json`)
- Automatic changelog generation

### Changed
- Updated installation documentation for all platforms

### Security
- Download verification protects against MITM attacks

---

## [1.6.0] - 2026-02-15

### Added
- USB-DLP Active Response scripts for data exfiltration prevention
- MITRE ATT&CK T1052.001 (Exfiltration Over Physical Medium) coverage
- MITRE ATT&CK T1200 (Hardware Additions) coverage
- Trivy vulnerability scanner integration (`-t` flag)
- Suricata IPS mode support (`-s ips` flag)
- Environment variables reference documentation

### Changed
- Improved cross-platform installation scripts
- Enhanced error handling in setup scripts

### Fixed
- Non-interactive Debian package upgrades

---

## [1.5.0] - 2026-01-20

### Added
- OAuth2 certificate-based authentication
- Wazuh Agent Status system tray application
- Yara malware scanning integration
- Snort/Suricata NIDS selection

### Changed
- Modular script architecture
- Platform-specific enrollment guides with screenshots

---

## [1.4.0] - 2025-12-15

### Added
- Initial cross-platform support (Linux, macOS, Windows)
- Automated Wazuh Agent installation
- Basic documentation

---

[Unreleased]: https://github.com/ADORSYS-GIS/wazuh-agent/compare/v1.6.0...HEAD
[1.6.0]: https://github.com/ADORSYS-GIS/wazuh-agent/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/ADORSYS-GIS/wazuh-agent/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/ADORSYS-GIS/wazuh-agent/releases/tag/v1.4.0
