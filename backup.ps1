# ============================================================================
# Script de sauvegarde automatique
# Créé par Dorian Delsarte (Alias Rin)
# Email: dorian.delsarte.informatique@gmail.com
# 
# Ce script permet de sauvegarder facilement vos dossiers importants.
# Il inclut :
# - Une interface interactive pour choisir les dossiers à sauvegarder
# - Une barre de progression pour suivre l'avancement
# - Des statistiques détaillées sur la sauvegarde
# - Une gestion intelligente des erreurs
# ============================================================================

# Configuration
$Config = @{
    # Chemins à sauvegarder (à personnaliser)
    SourcePaths = @(
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Pictures"
    )
    
    # Dossier de sauvegarde (à personnaliser)
    BackupRoot = "$env:USERPROFILE\Backups"
    
    # Logging
    LogFile = "$env:USERPROFILE\backup-tools\logs\backup.log"
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

# Fonction pour formater les tailles de fichiers de manière lisible
function Format-FileSize {
    param([long]$Size)
    $suffix = "B", "KB", "MB", "GB", "TB"
    $index = 0
    while ($Size -gt 1024 -and $index -lt $suffix.Count) {
        $Size = $Size / 1024
        $index++
    }
    return "{0:N2} {1}" -f $Size, $suffix[$index]
}

# Dossiers par défaut à sauvegarder
$DefaultPaths = @(
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Pictures",
    "$env:USERPROFILE\Desktop"
)

# Dossiers système Windows à ignorer (pour éviter les erreurs d'accès)
$SystemFolders = @(
    "Ma musique",
    "Mes images",
    "Mes vidéos"
)

# ============================================================================
# Début de l'interface utilisateur
# ============================================================================

Write-Host "`n=== Configuration de la sauvegarde ===" -ForegroundColor Cyan
Write-Host "Bienvenue dans l'outil de sauvegarde !" -ForegroundColor Green

# Demande du dossier de sauvegarde
$BackupRoot = Read-Host "Où souhaitez-vous stocker vos sauvegardes ? (par défaut: $env:USERPROFILE\Backups)"
if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = "$env:USERPROFILE\Backups"
}

# Demande des dossiers à sauvegarder
$SourcePaths = @()
Write-Host "`nQuels dossiers souhaitez-vous sauvegarder ?"
Write-Host "Entrez un chemin par ligne, ou appuyez sur Entrée pour terminer"
Write-Host "Voici les dossiers suggérés :"
foreach ($path in $DefaultPaths) {
    Write-Host "  - $path"
}
while ($true) {
    $path = Read-Host "Chemin"
    if ([string]::IsNullOrWhiteSpace($path)) { break }
    $SourcePaths += $path
}

# Si aucun chemin n'est spécifié, utiliser les suggestions
if ($SourcePaths.Count -eq 0) {
    Write-Host "`nJe vais utiliser les dossiers suggérés :" -ForegroundColor Yellow
    foreach ($path in $DefaultPaths) {
        Write-Host "  - $path"
    }
    $SourcePaths = $DefaultPaths
}

# Demande comment gérer les erreurs d'accès
Write-Host "`nComment souhaitez-vous gérer les erreurs d'accès ?" -ForegroundColor Cyan
Write-Host "1. Ignorer les erreurs et continuer (recommandé)"
Write-Host "2. Arrêter en cas d'erreur"
Write-Host "3. Me demander à chaque erreur"
$errorOption = Read-Host "Votre choix (1-3, par défaut: 1)"
if ([string]::IsNullOrWhiteSpace($errorOption)) { $errorOption = "1" }

# Vérification des chemins avant de commencer
$ValidPaths = @()
foreach ($Path in $SourcePaths) {
    if (Test-Path $Path) {
        $ValidPaths += $Path
    } else {
        Write-Log "Je ne trouve pas le dossier : $Path" "Yellow"
    }
}

if ($ValidPaths.Count -eq 0) {
    Write-Log "Désolé, je n'ai trouvé aucun dossier valide à sauvegarder." "Red"
    exit 1
}

# Demande si on veut garder une trace des opérations
$EnableLogging = Read-Host "Voulez-vous garder une trace des opérations dans un fichier log ? (O/N)"
$EnableLogging = $EnableLogging -eq "O" -or $EnableLogging -eq "o"
if ($EnableLogging) {
    $LogFile = Read-Host "Où souhaitez-vous stocker le fichier log ? (par défaut: $env:USERPROFILE\backup-tools\logs\backup.log)"
    if ([string]::IsNullOrWhiteSpace($LogFile)) {
        $LogFile = "$env:USERPROFILE\backup-tools\logs\backup.log"
    }
}

# ============================================================================
# Début de la sauvegarde
# ============================================================================

try {
    Write-Log "Je commence la sauvegarde..."
    
    # Création du dossier de sauvegarde avec la date
    $Date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $BackupDir = Join-Path $BackupRoot "Sauvegarde_$Date"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    
    # Statistiques globales
    $totalFiles = 0
    $totalSize = 0
    $copiedFiles = 0
    $copiedSize = 0
    $skippedFiles = 0
    $errorFiles = 0
    
    # Je compte d'abord tous les fichiers pour avoir une progression précise
    Write-Log "Je compte les fichiers à sauvegarder..."
    foreach ($Path in $ValidPaths) {
        Get-ChildItem -Path $Path -Recurse -File | ForEach-Object {
            $totalFiles++
            $totalSize += $_.Length
        }
    }
    
    # Sauvegarde des fichiers/dossiers
    $currentFile = 0
    foreach ($Path in $ValidPaths) {
        $Name = Split-Path $Path -Leaf
        $Dest = Join-Path $BackupDir $Name
        Write-Log "Je sauvegarde le dossier : $Path"
        
        try {
            # Copie récursive avec gestion des erreurs
            Get-ChildItem -Path $Path -Recurse | ForEach-Object {
                $currentFile++
                $percentComplete = [math]::Round(($currentFile / $totalFiles) * 100, 2)
                $currentSize = Format-FileSize $copiedSize
                $totalSizeFormatted = Format-FileSize $totalSize
                
                Write-Progress -Activity "Sauvegarde en cours" -Status "$percentComplete% ($currentSize / $totalSizeFormatted)" -PercentComplete $percentComplete -CurrentOperation $_.FullName
                
                $relativePath = $_.FullName.Substring($Path.Length)
                $targetPath = Join-Path $Dest $relativePath
                
                # Vérification des dossiers système
                $isSystemFolder = $false
                foreach ($sysFolder in $SystemFolders) {
                    if ($_.FullName -like "*\$sysFolder*") {
                        $isSystemFolder = $true
                        break
                    }
                }
                
                if ($isSystemFolder) {
                    Write-Log "  Je passe ce dossier système : $($_.FullName)" "Yellow"
                    $skippedFiles++
                    return
                }
                
                try {
                    if ($_.PSIsContainer) {
                        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                    } else {
                        Copy-Item $_.FullName -Destination $targetPath -Force
                        $copiedFiles++
                        $copiedSize += $_.Length
                    }
                } catch {
                    $errorMsg = "  Je n'ai pas pu accéder à : $($_.FullName)"
                    $errorFiles++
                    switch ($errorOption) {
                        "1" { Write-Log $errorMsg "Yellow" }
                        "2" { throw $errorMsg }
                        "3" {
                            $confirm = Read-Host "Je n'ai pas pu accéder à $($_.FullName). Voulez-vous continuer ? (O/N)"
                            if ($confirm -ne "O" -and $confirm -ne "o") {
                                throw "Opération annulée"
                            }
                        }
                    }
                }
            }
        } catch {
            Write-Log "Oups ! Une erreur s'est produite lors de la sauvegarde de $Path : $_" "Red"
            if ($errorOption -eq "2") { throw }
        }
    }
    
    # Effacer la barre de progression
    Write-Progress -Activity "Sauvegarde en cours" -Completed
    
    # Afficher le résumé
    Write-Log "`nVoici le résumé de la sauvegarde :" "Cyan"
    Write-Log "  J'ai copié $copiedFiles fichiers sur $totalFiles" "Green"
    Write-Log "  J'ai sauvegardé $(Format-FileSize $copiedSize) sur $(Format-FileSize $totalSize)" "Green"
    Write-Log "  J'ai ignoré $skippedFiles dossiers système" "Yellow"
    Write-Log "  J'ai rencontré $errorFiles erreurs d'accès" "Red"
    Write-Log "`nLa sauvegarde est terminée ! Tout est dans : $BackupDir" "Green"
} catch {
    Write-Log "Désolé, une erreur s'est produite : $_" "Red"
    exit 1
} 