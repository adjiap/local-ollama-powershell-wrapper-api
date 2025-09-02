# Mock helpers for consistent testing
function New-MockEnvironment {
  param(
    [hashtable]$EnvVars = @{
      'OPENWEBUI_API_KEY' = 'test-api-key-12345'
      'OPENWEBUI_URL' = 'http://localhost:3000/'
      'OLLAMA_API_TAGS' = 'ollama/api/tags'
      'OLLAMA_API_SINGLE_RESPONSE' = 'ollama/api/generate'
      'OLLAMA_API_CHAT' = 'ollama/api/chat'
    }
  )
  
  foreach ($var in $EnvVars.Keys) {
    [Environment]::SetEnvironmentVariable($var, $EnvVars[$var], 'Process')
  }
}

function Remove-MockEnvironment {
  param(
    [string[]]$VarNames = @(
      'OPENWEBUI_API_KEY', 'OPENWEBUI_URL', 'OLLAMA_API_TAGS',
      'OLLAMA_API_SINGLE_RESPONSE', 'OLLAMA_API_CHAT'
    )
  )
  
  foreach ($var in $VarNames) {
    [Environment]::SetEnvironmentVariable($var, $null, 'Process')
  }
}

function New-MockOllamaResponse {
  param(
    [string]$ResponseText = "This is a test response",
    [string]$Model = "llama3.2:3b",
    [int]$TotalDuration = 1000000000
  )
  
  return @{
    model = $Model
    response = $ResponseText
    total_duration = $TotalDuration
    created_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
  }
}

function New-MockChatResponse {
  param(
    [string]$ResponseText = "This is a test chat response",
    [string]$Model = "llama3.2:3b"
  )
  
  return @{
    model = $Model
    message = @{
      role = "assistant"
      content = $ResponseText
    }
    created_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
  }
}

function New-MockModelsResponse {
  return @{
    models = @(
      @{
        name = "llama3.2:3b"
        size = 2019393792
        modified_at = "2024-01-15T10:30:00Z"
      },
      @{
        name = "mistral:latest"
        size = 4108916224
        modified_at = "2024-01-10T14:20:00Z"
      },
      @{
        name = "codellama:7b"
        size = 3834089472
        modified_at = "2024-01-05T09:15:00Z"
      }
    )
  }
}

function Invoke-CommandInModule {
  param(
    [string]$CommandName, 
    [int]$Times = 1, 
    [scriptblock]$ParameterFilter
  )

  if ($ParameterFilter -and $ParameterFilter.ToString().Trim() -ne '') {
    Should -Invoke $CommandName -ModuleName OllamaOpenWebUIAPI -Times $Times -ParameterFilter $ParameterFilter
  } else {
    Should -Invoke $CommandName -ModuleName OllamaOpenWebUIAPI -Times $Times
  }
}
