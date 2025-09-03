function Initialize-OllamaEnvironment {
  <#
  .SYNOPSIS
    Validates and initializes the Ollama environment for API calls.

  .DESCRIPTION
    Centralizes all environment validation, URI construction, and model checking
    that's common across all Ollama functions. Returns a configuration object
    with validated settings or throws terminating errors for invalid configurations.

  .PARAMETER Model
    Optional model name to validate. If not provided, will use the first available model.

  .PARAMETER RequireModel
    If specified, throws an error if no model is provided and no models are available.

  .OUTPUTS
    PSCustomObject with the following properties:
    - Model: Validated model name
    - ChatApiUrl: Full URL for chat API endpoint
    - SingleResponseApiUrl: Full URL for single response API endpoint
    - Headers: Authentication headers for API calls
    - AvailableModels: Array of available model objects

  .EXAMPLE
    $config = Initialize-OllamaEnvironment
    # Uses first available model

  .EXAMPLE
    $config = Initialize-OllamaEnvironment -Model "llama3.2:3b"
    # Validates specified model

  .EXAMPLE
    $config = Initialize-OllamaEnvironment -RequireModel
    # Throws error if no models available

  .NOTES
    Required Environment Variables:
    - OPENWEBUI_API_KEY: API key for authentication
    - OPENWEBUI_URL: Base URL for the OpenWebUI instance

    Optional Environment Variables (will be set to defaults if missing):
    - OLLAMA_API_CHAT: Chat API endpoint (default: "ollama/api/chat")
    - OLLAMA_API_SINGLE_RESPONSE: Single response endpoint (default: "ollama/api/generate")
    - OLLAMA_API_TAGS: Model tags endpoint (default: "ollama/api/tags")
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$false)]
    [string]$Model,

    [Parameter(Mandatory=$false)]
    [switch]$RequireModel
  )

  #region Define Environment Variables
  $requiredEnvVars = @(
    'OPENWEBUI_API_KEY',
    'OPENWEBUI_URL'
  )
  
  $optionalEnvVars = @{
    'OLLAMA_API_CHAT' = "ollama/api/chat"
    'OLLAMA_API_SINGLE_RESPONSE' = "ollama/api/generate"
    'OLLAMA_API_TAGS' = "ollama/api/tags"
  }
  #endregion

  #region Check Required Variables
  $missingVars = @()
  foreach ($var in $requiredEnvVars) {
    if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue)) {
      $missingVars += $var
    }
  }

  if ($missingVars.Count -gt 0) {
    $errorMessage = "Missing required environment variables: $($missingVars -join ', '). " +
                   "Please set these environment variables before using Ollama functions."
    throw $errorMessage
  }
  #endregion

  #region Validate OPENWEBUI_URL (absolute URI)
  $openWebUIUrl = $env:OPENWEBUI_URL
  try {
    $uri = [System.Uri]::new($openWebUIUrl)
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http', 'https')) {
      throw "OPENWEBUI_URL is not a valid absolute URI: $openWebUIUrl"
    }
    Write-Verbose "Valid URI for OPENWEBUI_URL: $openWebUIUrl"
  } catch {
    throw "OPENWEBUI_URL is malformed: $openWebUIUrl. Error: $($_.Exception.Message)"
  }
  #endregion

  #region Set Optional Variables
  foreach ($var in $optionalEnvVars.Keys) {
    if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue)) {
      Write-Verbose "Setting default value for $var"
      [Environment]::SetEnvironmentVariable($var, $optionalEnvVars[$var], 'Process')
    }
  }
  #endregion

  #region Combine and Validate OLLAMA_API_* URIs
  $apiUrls = @{}
  foreach ($var in $optionalEnvVars.Keys) {
    $envValue = (Get-Item "env:$var").Value
    try {
      $baseUri = [System.Uri]::new($openWebUIUrl)
      $combinedUri = [System.Uri]::new($baseUri, $envValue)
      $fullUrl = $combinedUri.ToString()
      
      Write-Verbose "Valid combined URI for $var`: $fullUrl"
      $apiUrls[$var] = $fullUrl
      
      # Update environment variable with full URL
      [Environment]::SetEnvironmentVariable($var, $fullUrl, 'Process')
    } catch {
      throw "$var URL combination failed: $($_.Exception.Message)"
    }
  }
  #endregion

  #region Get Available Models
  Write-Verbose "Fetching available models..."
  $availableModels = Get-AvailableOllamaModels -ReturnFullResponse

  if ($availableModels.Count -eq 0) {
    throw "No models found or error connecting to API. Please check your connection and API configuration."
  }
  #endregion

  #region Validate or Select Model
  $selectedModel = $null
  if ($Model) {
    if ($Model -notin $availableModels.name) {
      throw "Model '$Model' not found. Available models: $($availableModels.name -join ', ')"
    }
    $selectedModel = $Model
    Write-Verbose "Using specified model: $selectedModel"
  } else {
    if ($RequireModel -and -not $selectedModel) {
      throw "Model is required but none was provided and no default could be determined."
    }
    $selectedModel = $availableModels[0].name
    Write-Verbose "Using default model: $selectedModel"
  }
  #endregion

  #region Create Configuration Object
  $headers = @{
    "Authorization" = "Bearer $env:OPENWEBUI_API_KEY"
    "Content-Type" = "application/json"
  }

  return [PSCustomObject]@{
    Model = $selectedModel
    ChatApiUrl = $apiUrls['OLLAMA_API_CHAT']
    SingleResponseApiUrl = $apiUrls['OLLAMA_API_SINGLE_RESPONSE']
    Headers = $headers
    AvailableModels = $availableModels
    OpenWebUIUrl = $openWebUIUrl
  }
  #endregion
}
