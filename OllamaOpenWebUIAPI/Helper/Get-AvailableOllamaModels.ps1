function Get-AvailableOllamaModels {
  <#
  .SYNOPSIS
    Retrieves a list of available Ollama models from the OpenWebUI API.

  .DESCRIPTION
    Makes an API call to the OpenWebUI tags endpoint to fetch all available Ollama models.
    By default, returns only the model names as strings. Use -ReturnFullResponse to get
    complete model objects with additional metadata.

  .PARAMETER ReturnFullResponse
    If specified, returns the complete model objects instead of just model names.
    Model objects contain additional metadata like size, modified date, etc.

  .OUTPUTS
    System.String[] (default)
    Returns an array of model names as strings.
    
    System.Object[] (with -ReturnFullResponse)
    Returns an array of complete model objects with full metadata.

  .EXAMPLE
    $modelNames = Get-AvailableOllamaModels
    Retrieves only the model names: @("llama3.2:3b", "mistral:latest", "codellama:7b")

  .EXAMPLE
    $fullModels = Get-AvailableOllamaModels -ReturnFullResponse
    Retrieves complete model objects with all metadata including size, modified date, etc.

  .EXAMPLE
    # Display available models in a user-friendly format
    Get-AvailableOllamaModels | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }

  .EXAMPLE
    # Check if a specific model is available
    $models = Get-AvailableOllamaModels
    if ("codellama:7b" -in $models) {
        Write-Host "CodeLlama is available for use"
    }

  .NOTES
    Requires the following environment variables:
    - OPENWEBUI_API_KEY: API key for authentication
    - OPENWEBUI_URL: Base URL for the OpenWebUI instance
    - OLLAMA_API_TAGS: API endpoint for model tags
    
    The function handles API errors gracefully and returns an empty array on failure.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$false)]
    [switch]$ReturnFullResponse
  )

  try {
    $headers = @{
      "Authorization" = "Bearer $env:OPENWEBUI_API_KEY"
    }
    
    $uri = "$env:OPENWEBUI_URL" + "$env:OLLAMA_API_TAGS"

    Write-Verbose "Making API call to $uri"
    Write-Verbose $headers
    
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop

    if ($ReturnFullResponse) {
        Write-Verbose "Returning full model objects"
        return $response.models
      } else {
        Write-Verbose "Returning model names only"
        return $response.models | ForEach-Object { $_.name }
      }
        
    } catch {
      Write-Host "Error fetching models: $($_.Exception.Message)" -ForegroundColor Red
      if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
      }
      return @()
  }
}
