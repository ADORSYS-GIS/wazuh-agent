## 1. SOC Concept for Wazuh
#### Objective
Design a Security Operations Center (SOC) framework that leverages Wazuh as the central platform for real-time threat detection, incident response, and compliance management, enabling proactive security operations and rapid incident resolution. 

### SOC Core Components
**1. Monitoring & Detection:** 
- **Wazuh Capabilities:** Utilize Wazuh’s file integrity monitoring (FIM), log analysis, and vulnerability detection.

- **Real-Time Analysis:** Deploy Wazuh agents across endpoints and servers for continuous monitoring of system logs, processes, and network activity.

- **Threat Intelligence:** Integrate Wazuh with external feeds and custom rules (Yara for malware, Snort for network threats) to enhance detection accuracy.

- **Anomaly Detection:** Leverage Wazuh’s built-in module to identify deviations from baseline behavior.

**2. Incident Response:**
- **Integration:** Connect Wazuh with Slack for real-time notifications, Jira for incident tracking.

- **Automation:** Use Wazuh’s Active Response module to execute predefined scripts (e.g., restart agent).



**3. Threat Intelligence:**
- **Feedback Loop:** Update detection rules based on post-incident analysis and emerging threats.

- **Custom Rules:** Develop and maintain a repository of Yara rules for malware detection.

**4. Compliance & Audit:**
- **Standards:** Align Wazuh configurations with frameworks like ISO 27001.

- **Reporting:** Generate automated compliance reports.

## 2.SOC Workflow with Wazuh

**i.  Alert Generation:** Wazuh detects a security event (e.g., brute force, malware, agent disconnection).

**ii.  Incident Classification:** Define severity (Low, Medium, High, Critical).

**iii.  Automated Notification and ticket creation:** 
- Alerts sent to Slack with relevant logs.
- Critical alerts → A Jira ticket is automatically created for tracking. (Based of wazuh rule [classification](https://documentation.wazuh.com/current/user-manual/ruleset/rules/rules-classification.html#rules-classification))


**iv.  Remediation:**

- **Manual:** Analysts use playbooks for in-depth investigation.

- **Auto-Remediation:** Wazuh Active Response executes predefined actions.

#### v. Post-Incident Review: 
SOC team documents findings and updates security policies.

<img src="/Agent Enrollment/images/Screenshot from 2025-04-03 18-23-02.png">


## 3. Demo Use Cases
### Use Case 1: Agent Disconnection
- Scenario: An agent disconnects for over an extended period of time.

- Response: Wazuh triggers an alert → Notifies Slack & Jira → Analyst investigates logs → Playbook guides resolution.

### Use Case 2: Brute Force Attack
- Scenario: Multiple failed SSH attempts detected from a single IP within 5 minutes.

- Response: Wazuh triggers Active Response → Blocks the attacker’s IP → Notifies SOC via Slack/Jira.