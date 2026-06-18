variable "packages" {
  type = list(object({
    Name     = string
    Version  = string
    Upgrade  = string
    Install  = string
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

# SSM Parameter Store - Package config (flat array as expected by the script)
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
      PackageNameArn:
        type: String
        default: '${aws_ssm_parameter.packages.arn}'
        description: The ARN of the parameter that includes the package names
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
                if (!(Test-Path "$($env:ProgramData)\chocolatey\choco.exe")) {
                  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                  Write-Output "Chocolatey installed successfully"
                }
                $env:Path += ";$($env:ProgramData)\chocolatey\bin"

                # Ensure Chocolatey is in system PATH permanently
                $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                $chocoPath = "$($env:ProgramData)\chocolatey\bin"
                if ($machinePath -notlike "*$chocoPath*") {
                  [Environment]::SetEnvironmentVariable("Path", "$machinePath;$chocoPath", "Machine")
                }

                $Packages = ((Get-SSMParameterValue -Name '{{ PackageNameArn }}').Parameters[0].Value) | ConvertFrom-Json
                Write-Output "Package list from the parameter store is $Packages"

                foreach ($Package in $Packages) {
                  if ($Package.Name -eq "") {
                    Write-Output "Package configuration missing Name. Skipping..."
                    continue
                  }
                  Write-Output "New Package - $($Package.Name)...."
                  $ChocoOutput = choco list $Package.Name -r -e

                  if (-not $ChocoOutput) {
                    if ($Package.Install -eq "yes") {
                      if ($Package.Version -eq "latest") {
                        Write-Output "Not installed. Installing latest version..."
                        choco install $Package.Name -r -y --no-progress $Package.Switches
                      } else {
                        Write-Output "Not installed. Installing version $($Package.Version)..."
                        choco install $Package.Name --version=$($Package.Version) -r -y --no-progress $Package.Switches
                      }
                    } else {
                      Write-Output "$($Package.Name) not installed. Install=no. Skipping..."
                    }
                  } elseif ($Package.Upgrade -eq "yes") {
                    $parts = $ChocoOutput.split('|')
                    $currentVersion = $parts[1]
                    if ($Package.Version -eq "latest") {
                      Write-Output "Installed ($currentVersion). Upgrading to latest..."
                      choco upgrade $Package.Name -r -y --no-progress $Package.Switches
                    } elseif ([System.Version]$Package.Version -gt [System.Version]$currentVersion) {
                      Write-Output "Installed ($currentVersion). Upgrading to $($Package.Version)..."
                      choco upgrade $Package.Name --version=$($Package.Version) -r -y --no-progress $Package.Switches
                    } else {
                      Write-Output "Installed ($currentVersion). Already at or above target. Skipping..."
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
    PackageNameArn = aws_ssm_parameter.packages.arn
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
