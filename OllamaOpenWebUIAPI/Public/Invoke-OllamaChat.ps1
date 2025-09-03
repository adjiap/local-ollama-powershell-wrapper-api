function Invoke-OllamaChat {
	<#
	.SYNOPSIS
		Sends a single prompt to Ollama models through OpenWebUI and returns the response.

	.DESCRIPTION
		The Invoke-OllamaChat function provides a simple interface to interact with Ollama language models
		through OpenWebUI. It supports system prompts, temperature control, token limits, and can return
		either just the response text or the full API response object.

		This function requires specific environment variables to be set for authentication and API endpoints.

	.PARAMETER Prompt
		The main prompt/question to send to the model. This is a required parameter.

	.PARAMETER Model
		The Ollama model to use for generation. Must be one of the available models.
		Defaults to the first found model in Ollama.

	.PARAMETER SystemPrompt
		Optional system prompt to set the behavior and context for the model.
		Default: "Only give short answers, with what is asked for"

	.PARAMETER Stream
		Enable streaming responses. Currently set to false by default.
		Default: $false

	.PARAMETER MaxTokens
		Maximum number of tokens to generate in the response. Controls response length.

	.PARAMETER Temperature
		Controls randomness in the response (0.0 to 1.0).
		- Lower values (0.1-0.3): More focused and deterministic
		- Higher values (0.7-1.0): More creative and random

	.PARAMETER ReturnFullResponse
		If specified, returns the complete API response object instead of just the response text.
		Useful for accessing metadata like timing, model info, etc.

	.INPUTS
		String. You can pipe a string containing the prompt to Invoke-OllamaChat.

	.OUTPUTS
		String. By default, returns the response text from the model.
		PSObject. If -ReturnFullResponse is used, returns the complete API response.

	.EXAMPLE
		Invoke-OllamaChat "What is DevSecOps?"
		
		Sends a basic question to the default model and returns the response.

	.EXAMPLE
		Invoke-OllamaChat "Explain containers" -Model "llama3.1:8b" -SystemPrompt "You are a Docker expert"
		
		Uses a specific model with a custom system prompt for specialized responses.

	.EXAMPLE
		$response = Invoke-OllamaChat "Tell me a story" -Model "mistral:7b" -Temperature 0.8 -MaxTokens 200
		
		Uses creative settings with higher temperature and token limit for storytelling.

	.EXAMPLE
		$fullResponse = Invoke-OllamaChat "Hello" -ReturnFullResponse
		$fullResponse.response          # The actual text
		$fullResponse.model            # Model used  
		$fullResponse.total_duration   # Performance metrics
		
		Returns the complete response object for accessing metadata.

	.NOTES  
		Required Environment Variables:
		- OPENWEBUI_API_KEY: Your OpenWebUI API key
		- OPENWEBUI_URL: Base URL for OpenWebUI (e.g., http://localhost:3000/)

		Optional Environment Variables:
		- OLLAMA_API_GENERATE: API endpoint for generation (e.g., ollama/api/generate)
		- OLLAMA_API_TAGS: API endpoint for model tags (e.g., ollama/api/tags)

	.FUNCTIONALITY
		This function provides single-shot interaction with Ollama models through OpenWebUI,
		supporting various configuration options for different use cases.

	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
		[string]$Prompt,

		[Parameter(Mandatory=$false)]
		[string]$Model,

		[Parameter(Mandatory=$false)]
		[string]$SystemPrompt = "Only give short answers, with what is asked for",

		[Parameter(Mandatory=$false)]
		[switch]$Stream = $false,

		[Parameter(Mandatory=$false)]
		[int]$MaxTokens,

		[Parameter(Mandatory=$false)]
		[float]$Temperature,

		[Parameter(Mandatory=$false)]
		[switch]$ReturnFullResponse
	)
	
	begin {
		$requiredEnvVars = @(
			'OPENWEBUI_API_KEY',
			'OPENWEBUI_URL'
		)
		$optionalEnvVars = @{
			'OLLAMA_API_SINGLE_RESPONSE' = "ollama/api/generate"
			'OLLAMA_API_TAGS'						 = "ollama/api/tags"
		}
		$missingVars = @()
		$uriValidationFailed = $false

		#region Check Required Variables
		foreach ($var in $requiredEnvVars) {
			if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue)) {
				$missingVars += $var
			}
		}
		if ($missingVars.Count -gt 0) {
			Write-Error "Missing required environment variables: $($missingVars -join ', ')"
			Write-Error "Add the environment variables first into your CLI"
			$abort = $true
		}
		#endregion

		#region Validate OPENWEBUI_URL (absolute URI)
		$openWebUIUrl = (Get-Item "env:OPENWEBUI_URL" -ErrorAction SilentlyContinue).Value
		if ($openWebUIUrl) {
			try {
				$uri = [System.Uri]::new($openWebUIUrl)
				if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http', 'https')) {
					Write-Error "OPENWEBUI_URL is not a valid absolute URI: $openWebUIUrl"
					$uriValidationFailed = $true
				} else {
					Write-Verbose "✓ Valid URI for OPENWEBUI_URL: $openWebUIUrl"
				}
			} catch {
				Write-Error "OPENWEBUI_URL is malformed: $openWebUIUrl"
				$uriValidationFailed = $true
			}
		}
		#endregion

		#region Set optional variables
    foreach ($var in $optionalEnvVars.Keys) {
			if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue)) {
				Write-Host "Using default value for $var" -ForegroundColor Yellow
				[Environment]::SetEnvironmentVariable($var, $optionalEnvVars[$var], 'Process')
			}
    }
		#endregion

		#region Combine and validate OLLAMA_API_* URIs
		$chatApiUrl = $null
		foreach ($var in $optionalEnvVars.Keys) {
			$envItem = Get-Item "env:$var" -ErrorAction SilentlyContinue
			if ($envItem -and $openWebUIUrl) {
				try {
					$baseUri = [System.Uri]::new($openWebUIUrl)
					$combinedUri = [System.Uri]::new($baseUri, $envItem.Value)
					$fullUrl = $combinedUri.ToString()
					
					Write-Host "✓ Valid combined URI for $var`: $fullUrl" -ForegroundColor Green
					[Environment]::SetEnvironmentVariable($var, $fullUrl, 'Process')
					
					# Store the chat API URL for later use
					if ($var -eq 'OLLAMA_API_SINGLE_RESPONSE') {
						$chatApiUrl = $fullUrl
					}
				} catch {
					Write-Error "$var URL combination failed: $($_.Exception.Message)"
					$uriValidationFailed = $true
				}
			}
		}
		
		if ($uriValidationFailed) {
			$abort = $true
		}
		#endregion

		#region Check for Model
		$availableModels = Get-AvailableOllamaModels -ReturnFullResponse

		if ($availableModels.Count -gt 0){
			if (-not $Model) {
				$Model = $availableModels[0].name # By default, use the first model found.
			} else {
				if ($Model -notin $availableModels.name) {
            Write-Error "Model '$Model' not found. Available models: $($availableModels.name -join ', ')"
            $abort = $true
        } else {
            Write-Verbose "✓ Using specified model: $Model"
        }
			}
		} else {
			Write-Error "No models found or error connecting to API"
			$abort = $true
		}
		#endregion
	}

	process {
		# Exits in case any of the checks in begin{} fails
		if ($abort) {
			return $null
		}
		Write-Verbose "Using model: $Model"
		Write-Verbose "Prompt: $Prompt"
		Write-Verbose "System prompt: $SystemPrompt"
		# Build request body
		$body = @{
			model = $Model
			system = $SystemPrompt
			prompt = $Prompt
			stream = $false
		}

		# Add optional parameters
		if ($MaxTokens) {
			$body.options = @{}
			$body.options.num_predict = $MaxTokens
		}

		if ($Temperature) {
			if (-not $body.options) { $body.options = @{} }
			$body.options.temperature = $Temperature
		}

		# Convert to JSON
		$jsonBody = $body | ConvertTo-Json -Depth 10

		# Setup headers
		$headers = @{
			"Authorization" = "Bearer $env:OPENWEBUI_API_KEY"
			"Content-Type" = "application/json"
		}

		try {
			Write-Verbose "Making API call to: $chatApiUrl"
			$response = Invoke-RestMethod -Uri $chatApiUrl -Method Post -Headers $headers -Body $jsonBody -ErrorAction Stop

			if ($ReturnFullResponse) {
				return $response
			} else {
				return $response.response
			}

		} catch {
				Write-Error "API call failed: $($_.Exception.Message)"
				if ($_.Exception.Response) {
					Write-Error "HTTP Status: $($_.Exception.Response.StatusCode)"
				}
				throw
		}
	}
}
