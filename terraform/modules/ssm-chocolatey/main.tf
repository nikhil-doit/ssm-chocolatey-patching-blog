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
  value = jsonencode({ Packages = var.packages })
}

# SSM Document - Chocolatey install/upgrade script
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
        inputs:
          runCommand:
            - |
              # Ensure Chocolatey is installed and in PATH
              $chocoPath = "C:\ProgramData\chocolatey\bin"
              if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                if (Test-Path "$chocoPath\choco.exe") {
                  # Chocolatey exists but not in PATH - add it
                  $env:Path += ";$chocoPath"
                } else {
                  # Fresh install
                  Set-ExecutionPolicy Bypass -Scope Process -Force
                  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                  # Remove partial install if exists
                  if (Test-Path "C:\ProgramData\chocolatey") {
                    Remove-Item "C:\ProgramData\chocolatey" -Recurse -Force
                  }
                  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                  $env:Path += ";$chocoPath"
                }
              }

              # Ensure Chocolatey is in system PATH permanently
              $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
              if ($currentPath -notlike "*$chocoPath*") {
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$chocoPath", "Machine")
              }

              # Verify choco is available
              if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                Write-Error "Chocolatey installation failed"
                exit 1
              }

              # Read package config from SSM Parameter Store
              $paramName = '{{ PackageParameterName }}'
              $paramValue = (Get-SSMParameter -Name $paramName).Value
              $config = $paramValue | ConvertFrom-Json

              foreach ($pkg in $config.Packages) {
                $name = $pkg.Name
                $version = $pkg.Version
                $upgrade = $pkg.Upgrade
                $switches = $pkg.Switches

                # Check if package is installed
                $installed = & choco list $name --local-only --exact 2>$null | Select-String $name

                if (-not $installed) {
                  # Install
                  if ($version -eq 'latest') {
                    $cmd = "choco install $name -y $switches"
                  } else {
                    $cmd = "choco install $name --version=$version -y $switches"
                  }
                  Write-Output "Installing: $cmd"
                  Invoke-Expression $cmd
                } elseif ($upgrade -eq 'yes') {
                  # Upgrade
                  if ($version -eq 'latest') {
                    $cmd = "choco upgrade $name -y $switches"
                  } else {
                    $cmd = "choco upgrade $name --version=$version -y $switches"
                  }
                  Write-Output "Upgrading: $cmd"
                  Invoke-Expression $cmd
                } else {
                  Write-Output "$name already installed, upgrade=no, skipping."
                }
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
