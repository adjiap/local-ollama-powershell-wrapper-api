<#
.SYNOPSIS
  Unit tests for Start-OllamaChatConversation function.

.DESCRIPTION
  This test module validates the Start-OllamaChatConversation function's setup and validation logic.
  
  TESTING APPROACH:
  Since Start-OllamaChatConversation is an interactive function with a continuous `while ($true)` loop
  that prompts for user input via Read-Host, traditional unit testing of the interactive conversation 
  flow is impractical and would require complex mocking of the entire conversation state machine.
  
  Instead, this test suite focuses on testing the non-interactive aspects:
  - Environment variable validation
  - Parameter acceptance and binding
  - Initial setup logic (model loading, configuration validation)
  - Function existence and basic structure
  
  WHAT IS NOT TESTED:
  - The interactive conversation loop itself
  - Command processing (exit, quit, clear, save, etc.)
  - Conversation state management
  - Real-time chat API interactions
  
  This approach allows us to validate the critical setup and validation logic while avoiding
  the complexity of mocking interactive user sessions. For integration testing of the full
  interactive experience, manual testing or specialized UI automation tools would be more appropriate.
  
  TESTING STRATEGY:
  - Test function existence and parameter structure
  - Test environment validation (required variables, URL format)
  - Test that setup logic executes (model loading, dependency injection)
  - Use ErrorAction and try/catch to handle expected failures during setup
  - Avoid executing the interactive loop by letting setup validation fail early

.NOTES
  This test module uses the simplified testing approach for interactive functions:
  1. Test what can be reliably mocked (setup, validation)
  2. Avoid testing complex interactive workflows 
  3. Focus on the function's contract and error handling
  4. Use parameter validation tests for interface testing
#>

BeforeAll {
  # Force remove any cached module first
  Get-Module OllamaOpenWebUIAPI | Remove-Module -Force -ErrorAction SilentlyContinue

  # Import module and test helpers
  $ModulePath = Join-Path $PSScriptRoot "../../OllamaOpenWebUIAPI"
  Import-Module $ModulePath -Force
  . "$PSScriptRoot/../Utils/MockHelpers.ps1"
}

Describe "Start-OllamaChatConversation" {
  BeforeEach {
    New-MockEnvironment
    Mock Get-AvailableOllamaModels { 
      return @(@{ name = "llama3.2:3b" }, @{ name = "mistral:latest" })
    } -ModuleName OllamaOpenWebUIAPI
  }

  AfterEach {
    Remove-MockEnvironment
  }

  Context "Environment validation" {
    It "Should exist as a command" {
      Get-Command Start-OllamaChatConversation | Should -Not -BeNullOrEmpty
    }

    It "Should validate required environment variables" {
      [Environment]::SetEnvironmentVariable('OPENWEBUI_API_KEY', $null, 'Process')
      
      { Start-OllamaChatConversation -ErrorAction Stop } | Should -Throw
    }

    It "Should validate OPENWEBUI_URL format" {
      [Environment]::SetEnvironmentVariable('OPENWEBUI_URL', 'invalid-url', 'Process')
      
      { Start-OllamaChatConversation -ErrorAction Stop } | Should -Throw
    }
  }

  Context "Model selection and setup" {
    It "Should call Get-AvailableOllamaModels during setup" {
      # This tests that the function gets to the model loading step
      try {
        Start-OllamaChatConversation -ErrorAction SilentlyContinue
      } catch {
        # Expected - function will fail when it hits interactive loop
      }
      
      Invoke-CommandInModule Get-AvailableOllamaModels -Times 1
    }
  }

  Context "Parameter acceptance" {
    It "Should accept Model parameter" {
      $command = Get-Command Start-OllamaChatConversation
      $command.Parameters.ContainsKey('Model') | Should -Be $true
    }

    It "Should accept LoadConversation parameter" {
      $command = Get-Command Start-OllamaChatConversation
      $command.Parameters.ContainsKey('LoadConversation') | Should -Be $true
    }
  }
}
