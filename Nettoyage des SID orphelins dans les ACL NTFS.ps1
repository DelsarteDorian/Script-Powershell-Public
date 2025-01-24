# Script PowerShell : Nettoyage des SID orphelins dans les ACL NTFS
# Auteur : Dorian Delsarte

param(
    [string]$ReportDir = "C:\rapport" # Dossier des rapports
)

Add-Type -AssemblyName Microsoft.VisualBasic

# Demande du mode (Test ou Suppression réelle) via une popup
$modeChoice = [Microsoft.VisualBasic.Interaction]::MsgBox(
    "Voulez-vous exécuter le script en mode test ?`n
    Oui : Mode Test (aucune suppression réelle)`n
    Non : Suppression des SID orphelins",
    4 + 32, 
    "Mode d'exécution"
)

if ($modeChoice -eq 6) {
    $TestMode = $true  # Mode Test sélectionné
    Write-Output "Mode Test activé : aucune suppression réelle ne sera effectuée."
} elseif ($modeChoice -eq 7) {
    $TestMode = $false # Suppression réelle sélectionnée
    Write-Output "Mode Suppression activé : les SID orphelins seront supprimés."
} else {
    Write-Output "Aucune sélection effectuée. Arrêt du script."
    exit
}

# Vérifie et crée le dossier de rapport si nécessaire
if (-not (Test-Path -Path $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
    Write-Output "Le dossier $ReportDir a été créé."
}

# Génère un nom de fichier unique pour le rapport
$timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$ReportPath = Join-Path -Path $ReportDir -ChildPath "ACLReport_$timestamp.txt"

# Demande du chemin cible via une popup
$Path = [Microsoft.VisualBasic.Interaction]::InputBox(
    "Entrez le chemin du dossier ou fichier cible :`n
    - Utilisez * pour scanner tout l'ordinateur.`n
    - Exemple : C:\Dossier\* pour scanner les fichiers dans ce dossier.",
    "Sélection du chemin cible",
    "C:\TestFolder"
)

# Vérifie si un chemin valide a été saisi
if ([string]::IsNullOrWhiteSpace($Path)) {
    Write-Output "Aucun chemin saisi. Arrêt du script."
    exit
}

# Vérifie que le chemin existe ou est valide (hors *)
if ($Path -notlike "*\*" -and -not (Test-Path -Path $Path)) {
    Write-Output "Erreur : Le chemin spécifié est invalide ou inaccessible : $Path"
    [System.Windows.Forms.MessageBox]::Show(
        "Le chemin spécifié est invalide ou inaccessible : $Path",
        "Erreur de chemin",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

# Fonction pour récupérer les fichiers et dossiers à analyser
function Get-TargetPaths {
    param (
        [string]$Path
    )
    if ($Path -eq "*") {
        # Récupère tous les fichiers sur l'ordinateur
        Write-Output "Analyse de tous les fichiers de l'ordinateur..."
        return Get-ChildItem -Path C:\ -Recurse -Force -ErrorAction SilentlyContinue
    } elseif ($Path -like "*\*") {
        # Récupère les fichiers correspondant à *
        $parentPath = Split-Path -Path $Path
        $filter = Split-Path -Leaf $Path

        if (-not (Test-Path -Path $parentPath)) {
            Write-Output "Erreur : Le dossier parent n'existe pas : $parentPath"
            return @() # Retourne une liste vide si le chemin est invalide
        }

        Write-Output "Analyse des fichiers dans : $parentPath avec filtre : $filter"
        return Get-ChildItem -Path $parentPath -Filter $filter -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        # Retourne directement le chemin saisi si aucun * n'est utilisé
        Write-Output "Analyse du chemin spécifié : $Path"
        return Get-Item -Path $Path -ErrorAction SilentlyContinue
    }
}

# Fonction pour lister les SID orphelins
function Get-OrphanedSID {
    param (
        [string]$Path
    )
    $acl = Get-Acl -Path $Path
    $orphans = @()
    
    foreach ($entry in $acl.Access) {
        try {
            # Vérifie si le SID correspond à un utilisateur/groupe valide
            $null = $entry.IdentityReference.Translate([System.Security.Principal.NTAccount])
        } catch {
            # Si une erreur survient, le SID est probablement orphelin
            $orphans += $entry.IdentityReference
        }
    }
    return $orphans
}

# Génération d'un rapport
function Generate-Report {
    param (
        [string]$ReportPath,
        [string]$Content
    )
    $Content | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Output "Rapport généré : $ReportPath"
    Start-Process notepad.exe $ReportPath # Ouvre automatiquement le fichier rapport
}

# Script principal
$targetPaths = Get-TargetPaths -Path $Path

# Vérifie si des chemins valides ont été trouvés
if ($targetPaths.Count -eq 0) {
    Write-Output "Erreur : Aucun fichier ou dossier valide trouvé pour le chemin spécifié."
    [System.Windows.Forms.MessageBox]::Show(
        "Aucun fichier ou dossier valide trouvé pour le chemin spécifié : $Path",
        "Erreur de chemin",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

$reportContent = "Rapport d'analyse des SID orphelins`n"
$reportContent += "Chemin cible : $Path`n"
$reportContent += "Date : $(Get-Date)`n"
$reportContent += "-------------------------------------`n"

foreach ($item in $targetPaths) {
    if (-not $item.FullName) {
        Write-Output "Chemin invalide ou inaccessible : $($item.FullName)"
        $reportContent += "Chemin invalide ou inaccessible : $($item.FullName)`n"
        continue
    }

    Write-Output "Analyse de : $($item.FullName)"
    $orphanedSIDs = Get-OrphanedSID -Path $item.FullName

    if ($orphanedSIDs.Count -eq 0) {
        $reportContent += "Aucun SID orphelin détecté dans $($item.FullName).`n"
    } else {
        $reportContent += "SIDs orphelins détectés dans $($item.FullName) :`n"
        $reportContent += ($orphanedSIDs -join "`n") + "`n"

        if (-not $TestMode) {
            foreach ($sid in $orphanedSIDs) {
                try {
                    $acl = Get-Acl -Path $item.FullName
                    $acl.Access | Where-Object { $_.IdentityReference -eq $sid } | ForEach-Object {
                        $acl.RemoveAccessRule($_)
                    }
                    Set-Acl -Path $item.FullName -AclObject $acl
                    $reportContent += "SID supprimé : $sid`n"
                } catch {
                    $reportContent += "Erreur lors de la suppression du SID : $sid`n"
                }
            }
        }
    }
}

# Génère le rapport final
Generate-Report -ReportPath $ReportPath -Content $reportContent
