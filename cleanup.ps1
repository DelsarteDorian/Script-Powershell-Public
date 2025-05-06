# ============================================================================
# Script de nettoyage automatique
# Créé par Dorian Delsarte (Alias Rin)
# Email: dorian.delsarte.informatique@gmail.com
# 
# Ce script permet de nettoyer facilement votre système.
# Il inclut :
# - Nettoyage des dossiers temporaires
# - Nettoyage du dossier Téléchargements
# - Vidage de la corbeille
# - Une interface interactive
# - Des logs détaillés
# ============================================================================

# Configuration
$Config = @{
    # Configuration du nettoyage
    Cleanup = @{
        # Dossiers à nettoyer
        TempFolders = @(
            $env:TEMP,
            "$env:USERPROFILE\AppData\Local\Temp"
        )
        
        # Dossier Téléchargements (optionnel)
        Downloads = "$env:USERPROFILE\Downloads"
        CleanDownloads = $false  # Mettre à $true pour activer le nettoyage des téléchargements
        
        # Corbeille
        CleanRecycleBin = $true
    }
    
    # Logging
    LogFile = "$env:USERPROFILE\backup-tools\logs\cleanup.log"
    EnableLogging = $true
}

# Fonction pour afficher les messages dans la console et les logs
function Write-Log {
    param($Message, $Color)
    if ($Config.EnableLogging) {
        $LogDir = Split-Path -Parent $Config.LogFile
        if (!(Test-Path $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        }
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$Timestamp - $Message" | Add-Content -Path $Config.LogFile
    }
    if ($Color) {
        Write-Host $Message -ForegroundColor $Color
    } else {
        Write-Host $Message
    }
}

# ============================================================================
# Début de l'interface utilisateur
# ============================================================================

Write-Host "`n=== Configuration du nettoyage ===" -ForegroundColor Cyan
Write-Host "Bienvenue dans l'outil de nettoyage !" -ForegroundColor Green

# Demande des dossiers temporaires à nettoyer
$TempFolders = @()
Write-Host "`nQuels dossiers temporaires souhaitez-vous nettoyer ?"
Write-Host "Entrez un chemin par ligne, ou appuyez sur Entrée pour terminer"
Write-Host "Exemple: $env:TEMP"
while ($true) {
    $path = Read-Host "Chemin"
    if ([string]::IsNullOrWhiteSpace($path)) { break }
    $TempFolders += $path
}

# Demande si on veut nettoyer les téléchargements
$CleanDownloads = Read-Host "Voulez-vous nettoyer votre dossier Téléchargements ? (O/N)"
$CleanDownloads = $CleanDownloads -eq "O" -or $CleanDownloads -eq "o"
if ($CleanDownloads) {
    $Downloads = Read-Host "Où se trouve votre dossier Téléchargements ? (par défaut: $env:USERPROFILE\Downloads)"
    if ([string]::IsNullOrWhiteSpace($Downloads)) {
        $Downloads = "$env:USERPROFILE\Downloads"
    }
}

# Demande si on veut vider la corbeille
$CleanRecycleBin = Read-Host "Voulez-vous vider votre corbeille ? (O/N)"
$CleanRecycleBin = $CleanRecycleBin -eq "O" -or $CleanRecycleBin -eq "o"

# Demande si on veut garder une trace des opérations
$EnableLogging = Read-Host "Voulez-vous garder une trace des opérations dans un fichier log ? (O/N)"
$EnableLogging = $EnableLogging -eq "O" -or $EnableLogging -eq "o"
if ($EnableLogging) {
    $LogFile = Read-Host "Où souhaitez-vous stocker le fichier log ? (par défaut: $env:USERPROFILE\backup-tools\logs\cleanup.log)"
    if ([string]::IsNullOrWhiteSpace($LogFile)) {
        $LogFile = "$env:USERPROFILE\backup-tools\logs\cleanup.log"
    }
}

# ============================================================================
# Début du nettoyage
# ============================================================================

try {
    Write-Log "Je commence le nettoyage..."
    
    # Nettoyage des dossiers temporaires
    foreach ($TempFolder in $TempFolders) {
        if (Test-Path $TempFolder) {
            Write-Log "Je nettoie le dossier temporaire : $TempFolder"
            Remove-Item -Path "$TempFolder\*" -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Log "Je ne trouve pas le dossier : $TempFolder" "Yellow"
        }
    }
    
    # Vidage de la corbeille si activé
    if ($CleanRecycleBin) {
        Write-Log "Je vide votre corbeille..."
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.Namespace(0xA)
        $recycleBin.Items() | ForEach-Object { 
            Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue 
        }
    }
    
    # Nettoyage du dossier Téléchargements si activé
    if ($CleanDownloads) {
        if (Test-Path $Downloads) {
            Write-Log "Je nettoie votre dossier Téléchargements..."
            Remove-Item -Path "$Downloads\*" -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Log "Je ne trouve pas votre dossier Téléchargements : $Downloads" "Yellow"
        }
    }
    
    Write-Log "Le nettoyage est terminé !" "Green"
} catch {
    Write-Log "Oups ! Une erreur s'est produite : $_" "Red"
    exit 1
} 