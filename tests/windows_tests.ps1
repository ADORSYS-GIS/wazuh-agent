# tests/windows_tests.ps1
$ErrorActionPreference = 'Stop'

Describe "Wazuh Windows Installation Tests" {
    BeforeAll {
        # Set paths based on Windows installation
        $OSSEC_PATH = "C:\Program Files (x86)\ossec-agent"
        $OSSEC_CONF_PATH = "$OSSEC_PATH\ossec.conf"
        $YARA_RULES_PATH = "$OSSEC_PATH\ruleset\yara\rules"
        $ACTIVE_RESPONSE_PATH = "$OSSEC_PATH\active-response\bin"
        
        # Determine if we're running with admin privileges
        $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    Context "Core Wazuh Installation" {
        It "Wazuh directory exists" {
            Test-Path $OSSEC_PATH | Should -Be $true
        }

        It "ossec.conf exists" {
            Test-Path $OSSEC_CONF_PATH | Should -Be $true
        }

        It "Wazuh service is running" {
            $service = Get-Service -Name "OssecSvc" -ErrorAction SilentlyContinue
            $service.Status | Should -Be "Running"
        }
    }

    Context "YARA Installation" {
        It "YARA executable is in PATH" {
            { Get-Command yara -ErrorAction Stop } | Should -Not -Throw
        }

        It "YARA script exists" {
            Test-Path "$ACTIVE_RESPONSE_PATH\yara.ps1" | Should -Be $true
        }

        It "YARA rules directory exists" {
            if ($IsAdmin) {
                Test-Path $YARA_RULES_PATH | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "Admin rights required to check protected paths"
            }
        }
    }

    Context "OAuth2 Client Installation" {
        It "OAuth2 client files exist" {
            $clientFiles = @(
                "$OSSEC_PATH\bin\wazuh-cert-oauth2-client.exe",
                "$OSSEC_PATH\etc\cert_oauth2.conf"
            )
            foreach ($file in $clientFiles) {
                Test-Path $file | Should -Be $true
            }
        }
    }

    Context "Agent Status Installation" {
        It "Agent status script exists" {
            Test-Path "$ACTIVE_RESPONSE_PATH\agent-status.ps1" | Should -Be $true
        }
    }

    Context "Version File" {
        It "Version file exists" {
            Test-Path "$OSSEC_PATH\version.txt" | Should -Be $true
        }
    }

    # Conditional tests based on installation options
    if ($env:INSTALL_SNORT -eq "TRUE") {
        Context "Snort Installation" {
            It "Snort is installed" {
                { Get-Command snort -ErrorAction Stop } | Should -Not -Throw
            }

            It "Snort service is running" {
                (Get-Service -Name "Snort" -ErrorAction SilentlyContinue).Status | Should -Be "Running"
            }
        }
    }

    if ($env:INSTALL_SURICATA -eq "TRUE") {
        Context "Suricata Installation" {
            It "Suricata is installed" {
                { Get-Command suricata -ErrorAction Stop } | Should -Not -Throw
            }

            It "Suricata service is running" {
                (Get-Service -Name "Suricata" -ErrorAction SilentlyContinue).Status | Should -Be "Running"
            }
        }
    }
}