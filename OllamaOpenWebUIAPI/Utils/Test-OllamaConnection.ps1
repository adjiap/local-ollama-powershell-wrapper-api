function Test-OllamaConnection {
  <#
  .SYNOPSIS
    Tests connectivity to the Ollama API through OpenWebUI.

  .DESCRIPTION
    Performs a quick connectivity test to verify that the API is reachable
    and authentication is working properly.

  .OUTPUTS
    Boolean. Returns $true if connection is successful, $false otherwise.

  .EXAMPLE
    if (Test-OllamaConnection) {
      Write-Host "API is reachable"
    } else {
      Write-Host "API connection failed"
    }

  .NOTES
    Uses the same environment variables as other Ollama functions.
    This is a lightweight test that only checks basic connectivity.
  #>
  [CmdletBinding()]
  param()

  try {
    $models = Get-AvailableOllamaModels -ErrorAction Stop
    return $models.Count -gt 0
  } catch {
    Write-Verbose "Connection test failed: $($_.Exception.Message)"
    return $false
  }
}
