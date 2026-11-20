# Reglas de PSScriptAnalyzer para este repo. Las usa la skill actualizar-version-scripts.
# Corren todas las reglas normales; lo que es intencional se marca en cada script con SuppressMessageAttribute.
@{
    Rules = @{
        # Los .bat abren los scripts con PowerShell 5.1: avisa si algo solo existe en PowerShell 7.
        # El perfil win-48 es Windows 10 Pro (los win-8 son Windows Server).
        PSUseCompatibleSyntax   = @{ Enable = $true; TargetVersions = @('5.1') }
        PSUseCompatibleCommands = @{ Enable = $true; TargetProfiles = @('win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework') }
    }
}
