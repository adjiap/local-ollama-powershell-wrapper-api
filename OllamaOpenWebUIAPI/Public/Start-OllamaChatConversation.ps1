function Start-OllamaChatConversation {
	<#
	.SYNOPSIS
		Starts an interactive chat conversation with an Ollama model.

	.DESCRIPTION
		Initializes and manages an interactive chat session with a specified Ollama model through the OpenWebUI API.
		Supports conversation history, model switching, and various interactive commands.

	.PARAMETER Model
		The name of the Ollama model to use for the conversation.

	.PARAMETER SystemPrompt
		The system prompt that defines the AI's behavior and context. Default is "Only give short answers, with what is asked for".

	.PARAMETER LoadConversation
		Path to a JSON file containing a previously saved conversation to resume. The file should contain a valid conversation history.

	.EXAMPLE
		Start-OllamaChatConversation
		Starts a chat session with default settings.

	.EXAMPLE
		Start-OllamaChatConversation -Model "llama3.2:1b" -SystemPrompt "You are a helpful assistant"
		Starts a chat session with a specific model and custom system prompt.

	.EXAMPLE
		Start-OllamaChatConversation -LoadConversation "conversation_20240101_120000.json"
		Resumes a previously saved conversation.

	.NOTES
		Interactive Commands Available During Chat:
		- 'exit' or 'quit': Exit the chat session
		- 'clear': Clear conversation history and start fresh
		- 'save': Save current conversation to timestamped JSON file
		- 'count': Display number of messages in conversation
		- 'model': Change the active model during conversation
		- 'set-system': Change the system prompt during conversation

		Environment Variables Required:
		- OPENWEBUI_API_KEY: Bearer token for API authentication
		- OPENWEBUI_URL: Base URL for OpenWebUI instance

		Optional Environment Variables:
		- OLLAMA_API_CHAT: API Endpoint for chat completions (e.g., ollama/api/chat)
		- OLLAMA_API_TAGS: API Endpoint for available models tags (e.g., ollama/api/tags)
	
	.FUNCTIONALITY
		This function starts a conversation with Ollama models through PowerShell CLI
		using OpenWebUI API
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$false)]
		[string]$Model,

		[Parameter(Mandatory=$false)]
		[string]$SystemPrompt = "Only give short answers, with what is asked for",

		[Parameter(Mandatory=$false)]
		[string]$LoadConversation
	)

	begin {
		#region Check Environment Variables
		$requiredEnvVars = @(
			'OPENWEBUI_API_KEY',
			'OPENWEBUI_URL'
		)
		$optionalEnvVars = @{
			'OLLAMA_API_CHAT' = "ollama/api/chat"
			'OLLAMA_API_TAGS'	=	"ollama/api/tags"
		}
		$missingVars = @()
		$uriValidationFailed = $false

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
		
		# Validate OPENWEBUI_URL (absolute URI)
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
		
		# Set optional variables with defaults if not present
    foreach ($var in $optionalEnvVars.Keys) {
			if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue)) {
				Write-Host "Using default value for $var" -ForegroundColor Yellow
				[Environment]::SetEnvironmentVariable($var, $optionalEnvVars[$var], 'Process')
			}
    }
		# Combine and validate OLLAMA_API_* URIs
		$chatApiUrl = $null
		foreach ($var in $optionalEnvVars.Keys) {
			$envItem = Get-Item "env:$var" -ErrorAction SilentlyContinue
			if ($envItem -and $openWebUIUrlItem) {
				try {
					$baseUri = [System.Uri]::new($openWebUIUrlItem.Value)
					$combinedUri = [System.Uri]::new($baseUri, $envItem.Value)
					$fullUrl = $combinedUri.ToString()
					
					Write-Host "✓ Valid combined URI for $var`: $fullUrl" -ForegroundColor Green
					[Environment]::SetEnvironmentVariable($var, $fullUrl, 'Process')
					
					# Store the chat API URL for later use
					if ($var -eq 'OLLAMA_API_CHAT') {
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


		#region Displaying Models
		Write-Host "Fetching available models..." -ForegroundColor Gray
		$availableModels = Get-AvailableOllamaModels -ReturnFullResponse

		if ($availableModels.Count -gt 0){
			Write-Host "Available models:" -ForegroundColor Green
			$availableModels | ForEach-Object {
				Write-Host "    - $($_.name)" -ForegroundColor Cyan
			}
			$Model = $availableModels[0].name # By default, use the first model found.
			Write-Verbose "Using default model: $Model"
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
		#region Load Old Conversation
		if ($LoadConversation -and (Test-Path $LoadConversation)) {
			$messages = Get-Content $LoadConversation | ConvertFrom-Json
			Write-Host "Loaded conversation from $LoadConversation" -ForegroundColor Green
		} else {
			$messages = @(
				@{
					role = "system"
					content = $SystemPrompt
				}
			)
		}
		#endregion

		#region Main Conversation Loop
		Write-Host ""
		Write-Host "Chat with $Model" -ForegroundColor Green
		Write-Host "Available commands: exit, quit, clear, save, count, model, set-system" -ForegroundColor Yellow

		while ($true) {
			Write-Host ""  # Empty line before prompt
			$userInput = Read-Host "You"

			if ($userInput.ToLower() -eq "exit" -or $userInput.ToLower() -eq "quit") {
				Write-Host "Goodbye!" -ForegroundColor Yellow
				return 
			}
			elseif ($userInput.ToLower() -eq "clear") {
				$messages = @(@{role = "system"; content = $SystemPrompt})
				Write-Host "Conversation cleared!" -ForegroundColor Yellow
				continue
			}
			elseif ($userInput.ToLower() -eq "save") {
				$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
				$filename = "conversation_$timestamp.json"
				$messages | ConvertTo-Json -Depth 10 | Out-File $filename
				Write-Host "Saved to $filename" -ForegroundColor Green
				continue
			}
			elseif ($userInput.ToLower() -eq "count") {
				Write-Host "Messages in conversation: $($messages.Count)" -ForegroundColor Gray
				continue
			}
			elseif ($userInput.ToLower() -eq "model") {
				Write-Host ""
				Write-Host "Available models:" -ForegroundColor Green
				$availableModels | ForEach-Object { Write-Host "  - $($_.name)" -ForegroundColor Cyan }
				
				Write-Host ""
				$newModel = Read-Host "Enter new model name (or press Enter to keep current)"
				if ($newModel -and $newModel.Trim() -ne "") {
					$Model = $newModel.Trim()
					Write-Host "Changed model to: $Model" -ForegroundColor Green
				}
				continue
			}
			elseif ($userInput.ToLower() -eq "set-system") {
				Write-Host ""
				Write-Host "Current System Prompt: $SystemPrompt" -ForegroundColor Gray

				$newSystemPrompt = Read-Host "Enter new system prompt (or press Enter to keep current)"
				if ($newSystemPrompt -and $newSystemPrompt.Trim() -ne "") {
					$SystemPrompt = $newSystemPrompt.Trim()
				}
				continue
			}
			
			# Add user message
			$messages += @{role = "user"; content = $userInput}
			
			# API call
			$headers = @{
				"Authorization" = "Bearer $env:OPENWEBUI_API_KEY"
				"Content-Type" = "application/json"
			}
			
			$body = @{
				model = $Model
				messages = $messages
				stream = $false
			}
			
			$jsonBody = $body | ConvertTo-Json -Depth 10
			
			try {		
				Write-Verbose "Making API call to $chatApiUrl"
				Write-Verbose "Using model $Model"
				Write-Verbose "System Prompt: $SystemPrompt"
				
				$response = Invoke-RestMethod -Uri $chatApiUrl -Method Post -Headers $headers -Body $jsonBody
				$assistantResponse = $response.message.content
				
				Write-Host ""
				Write-Host "Assistant: " -ForegroundColor Cyan -NoNewline
				Write-Host $assistantResponse
				
				# Add response to history
				$messages += @{role = "assistant"; content = $assistantResponse}
					
			} catch {
					Write-Host ""
					Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
					# Remove the user message if API call failed
					$messages = $messages[0..($messages.Count-2)]
			}
		}
		#endregion
	}   
	end {
		Write-Verbose "Chat Session ended"
	}
}
