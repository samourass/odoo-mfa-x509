<#
 Installe la CA et le certificat client sur Windows, et ajoute l'entrée hosts.
 Dossier d'exécution : n'importe lequel (PowerShell, idéalement en administrateur).
 Exemple :
   .\windows\install-client-cert.ps1 -VmUser USER -VmIp 192.168.1.50 -ClientName samar
#>
param(
  [Parameter(Mandatory = $true)][string]$VmUser,
  [Parameter(Mandatory = $true)][string]$VmIp,
  [string]$ClientName = "samar",
  [string]$Fqdn = "odoo-mfa-server",
  [string]$RemoteRoot = "/opt/odoo-mfa"
)
$ErrorActionPreference = "Stop"
$dest = Join-Path $env:USERPROFILE "Documents\pki-odoo"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

scp "${VmUser}@${VmIp}:${RemoteRoot}/pki/ca/ca.crt" "$dest\ca.crt"
scp "${VmUser}@${VmIp}:${RemoteRoot}/pki/clients/$ClientName.p12" "$dest\$ClientName.p12"

# Confiance envers la CA interne (Windows peut demander une confirmation)
Import-Certificate -FilePath "$dest\ca.crt" -CertStoreLocation Cert:\CurrentUser\Root | Out-Null

# Import du certificat client (le mot de passe du .p12 est demandé)
certutil -user -importPFX "$dest\$ClientName.p12"

# Résolution de nom
$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
  if (-not (Select-String -Path $hosts -Pattern $Fqdn -Quiet)) { Add-Content $hosts "$VmIp $Fqdn" }
  Write-Host "Entrée hosts OK."
} else {
  Write-Warning "Relancez en administrateur ou ajoutez manuellement : '$VmIp $Fqdn' dans $hosts"
}
Write-Host "Terminé. Ouvrez https://$Fqdn et choisissez le certificat '$ClientName'."
