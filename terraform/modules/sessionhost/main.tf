terraform {
  required_version = "~> 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.24"
    }
  }
}

resource "azurerm_network_interface" "this" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "this" {
  name                = var.vm_name
  computer_name       = var.computer_name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.this.id
  ]
  provision_vm_agent        = true
  automatic_updates_enabled = false
  patch_mode                = "Manual"
  tags                      = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_virtual_machine_extension" "aad_login" {
  count                      = var.enable_aad_login_extension ? 1 : 0
  name                       = "${var.vm_name}-aadlogin"
  virtual_machine_id         = azurerm_windows_virtual_machine.this.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "2.2"
  auto_upgrade_minor_version = true
}

locals {
  avd_register_ps = <<-PS
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'Continue'

$log = Join-Path $env:TEMP 'avd_register.log'
Start-Transcript -Path $log -Force

try {
  $token = '${var.registration_token}'
  $agent = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv'
  $boot  = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'

  try {
    Start-Service -Name msiserver -ErrorAction Stop
  } catch {
    Write-Warning ("Could not start msiserver: {0}" -f $_.Exception.Message)
  }

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $tmp = $env:TEMP
  $agentMsi = Join-Path $tmp 'AVDAgent.msi'
  $bootMsi  = Join-Path $tmp 'AVDBootLoader.msi'
  $agentLog = Join-Path $tmp 'AVDAgent-install.log'
  $bootLog  = Join-Path $tmp 'AVDBootLoader-install.log'

  Invoke-WebRequest -Uri $agent -OutFile $agentMsi -UseBasicParsing
  Invoke-WebRequest -Uri $boot -OutFile $bootMsi -UseBasicParsing

  $p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$agentMsi`" /quiet /norestart /l*v `"$agentLog`" REGISTRATIONTOKEN=$token"
  if ($p.ExitCode -ne 0) {
    throw "AVDAgent MSI failed with exit code $($p.ExitCode). Review transcript $log and MSI log $agentLog."
  }

  $p2 = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$bootMsi`" /quiet /norestart /l*v `"$bootLog`""
  if ($p2.ExitCode -ne 0) {
    throw "AVDBootLoader MSI failed with exit code $($p2.ExitCode). Review transcript $log and MSI log $bootLog."
  }

  try { Set-Service -Name RDAgentBootLoader -StartupType Automatic } catch {}
  try { Start-Service -Name RDAgentBootLoader -ErrorAction SilentlyContinue } catch {}

  $bootOk = $false
  for ($i = 1; $i -le 12; $i++) {
    $svc = Get-Service -Name RDAgentBootLoader -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') { $bootOk = $true; break }
    Start-Sleep -Seconds 10
    try { Start-Service -Name RDAgentBootLoader -ErrorAction SilentlyContinue } catch {}
  }

  try { Restart-Service -Name RdAgent -Force } catch {}
  Start-Sleep -Seconds 15

  if (-not $bootOk) {
    throw "RDAgentBootLoader did not reach Running state after waiting ~120s. Review transcript $log plus MSI logs $agentLog and $bootLog."
  }
}
finally {
  Stop-Transcript
}
PS
}

resource "azurerm_virtual_machine_extension" "avd_register" {
  name                       = "${var.vm_name}-avd-register-${substr(sha256(var.registration_token), 0, 8)}"
  virtual_machine_id         = azurerm_windows_virtual_machine.this.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell -NoProfile -ExecutionPolicy Bypass -Command \"$ErrorActionPreference='Stop'; $ps1=Join-Path $env:TEMP 'avd_register.ps1'; $b64='${base64encode(local.avd_register_ps)}'; $script=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64)); Set-Content -Path $ps1 -Value $script -Encoding UTF8 -Force; powershell -NoProfile -ExecutionPolicy Bypass -File $ps1\""
    force_rerun      = timestamp()
  })

  depends_on = [
    azurerm_virtual_machine_extension.aad_login
  ]
}
