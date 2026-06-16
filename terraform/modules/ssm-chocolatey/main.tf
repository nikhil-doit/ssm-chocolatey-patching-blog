variable "packages" {
  type = list(object({
    Name     = string
    Version  = string
    Upgrade  = string
    Switches = string
  }))
  description = "List of Chocolatey packages to manage"
}

variable "association_schedule" {
  type    = string
  default = "rate(1 day)"
}

variable "target_tag_key" {
  type    = string
  default = "PatchGroup"
}

variable "target_tag_value" {
  type    = string
  default = "chocolatey"
}

# SSM Parameter Store - Package config
resource "aws_ssm_parameter" "packages" {
  name  = "/chocolatey/packages"
  type  = "String"
  value = jsonencode(var.packages)
}

# SSM Document - Chocolatey install/upgrade script (based on AWS blog approach)
resource "aws_ssm_document" "chocolatey" {
  name            = "SSM-Chocolatey-ManagePackages"
  document_type   = "Command"
  document_format = "YAML"

  content = <<-DOC
    schemaVersion: '2.2'
    description: Install and manage packages via Chocolatey
    parameters:
      PackageParameterName:
        type: String
        default: '${aws_ssm_parameter.packages.name}'
        description: SSM Parameter Store name containing package list
    mainSteps:
      - action: aws:runPowerShellScript
        name: InstallAndManageChocolateyPackages
        precondition:
          StringEquals:
            - platformType
            - Windows
        inputs:
          timeoutSeconds: '3600'
          runCommand:
            - |
              try {
                # Install Chocolatey if not present
                if (!(Test-Path "$($env:ProgramData)\chocolatey\choco.exe")) {
                  Set-ExecutionPolicy Bypass -Scope Process -Force
                  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                  iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                  Write-Output "Chocolatey installed successfully"
                }

                # Add Chocolatey to PATH for this session
                $env:Path += ";$($env:ProgramData)\chocolatey\bin"

                # Ensure Chocolatey is in system PATH permanently
                $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                $chocoPath = "$($env:ProgramData)\chocolatey\bin"
                if ($machinePath -notlike "*$chocoPath*") {
                  [Environment]::SetEnvironmentVariable("Path", "$machinePath;$chocoPath", "Machine")
                }

                # Read package config from SSM Parameter Store
                $Packages = ((Get-SSMParameterValue -Name '{{ PackageParameterName }}').Parameters[0].Value) | ConvertFrom-Json
                Write-Output "Package list from parameter store: $Packages"

                foreach ($Package in $Packages) {
                  Write-Output "Processing package: $($Package.Name)..."

                  # Check if package is installed using parseable output
                  $ChocoOutput = choco list $Package.Name -r -e

                  if (-not $ChocoOutput) {
                    # Package not installed - install it
                    if ($Package.Version -eq "latest") {
                      Write-Output "Not installed. Installing latest version..."
                      choco install $Package.Name -r -y --no-progress $Package.Switches
                    } else {
                      Write-Output "Not installed. Installing version $($Package.Version)..."
                      choco install $Package.Name --version=$($Package.Version) -r -y --no-progress $Package.Switches
                    }
                  } elseif ($Package.Upgrade -eq "yes") {
                    # Package installed and upgrade=yes
                    $parts = $ChocoOutput.split('|')
                    $currentVersion = $parts[1]
                    if ($Package.Version -eq "latest") {
                      Write-Output "Installed ($currentVersion). Upgrade=yes. Upgrading to latest..."
                      choco upgrade $Package.Name -r -y --no-progress $Package.Switches
                    } elseif ([System.Version]$Package.Version -gt [System.Version]$currentVersion) {
                      Write-Output "Installed ($currentVersion). Upgrading to $($Package.Version)..."
                      choco upgrade $Package.Name --version=$($Package.Version) -r -y --no-progress $Package.Switches
                    } else {
                      Write-Output "Installed ($currentVersion). Already at or above target version. Skipping..."
                    }
                  } elseif ($Package.Upgrade -eq "no") {
                    Write-Output "Installed. Upgrade=no. Skipping..."
                  }
                }
              } catch {
                Write-Error "An error occurred:"
                Write-Error $_
              }
  DOC
}

# SSM State Manager Association - runs on schedule
resource "aws_ssm_association" "chocolatey" {
  name             = aws_ssm_document.chocolatey.name
  association_name = "Chocolatey-Package-Management"

  schedule_expression = var.association_schedule

  targets {
    key    = "tag:${var.target_tag_key}"
    values = [var.target_tag_value]
  }

  parameters = {
    PackageParameterName = aws_ssm_parameter.packages.name
  }
}

# Outputs
output "parameter_arn" {
  value = aws_ssm_parameter.packages.arn
}

output "document_name" {
  value = aws_ssm_document.chocolatey.name
}

output "association_id" {
  value = aws_ssm_association.chocolatey.association_id
}
