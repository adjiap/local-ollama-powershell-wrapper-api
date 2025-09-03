# Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Helper = @( Get-ChildItem -Path $PSScriptRoot\Helper\*.ps1 -ErrorAction SilentlyContinue )
$Utils = @( Get-ChildItem -Path $PSScriptRoot\Utils\*.ps1 -ErrorAction SilentlyContinue )

# Dot source the files
Foreach($import in @($Public + $Helper + $Utils)) {
  Try {
    . $import.fullname
  } Catch {
    Write-Error -Message "Failed to import function $($import.fullname): $_"
  }
}
