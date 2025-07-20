#Get public and private function definition files.
  $Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
  $Helper = @( Get-ChildItem -Path $PSScriptRoot\Helper\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
  Foreach($import in @($Public + $Helper))
  {
    Try
    {
      . $import.fullname
    }
    Catch
    {
      Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
  }

Export-ModuleMember -Function $Helper.Basename
Export-ModuleMember -Function $Public.Basename
