<#
.SYNOPSIS
  Unit tests for Invoke-OllamaChat function.

.DESCRIPTION
  This test module validates the Invoke-OllamaChat function's API interaction, parameter handling,
  and error management for single-prompt chat operations.
  
  TESTING APPROACH:
  Invoke-OllamaChat is a synchronous API wrapper function that processes single prompts through
  the Ollama chat API. Unlike the batch and conversation functions, this function has a
  straightforward execution flow that is well-suited for comprehensive unit testing:
  
  1. Parameter validation and model selection
  2. Request body construction with various options
  3. HTTP API call to Ollama endpoint
  4. Response processing and formatting
  
  TESTING STRATEGY:
  This test suite uses thorough mocking to isolate the function and validate its behavior:
  
  - Mock all external dependencies (Get-AvailableOllamaModels, Invoke-RestMethod)
  - Test parameter validation and transformation logic
  - Verify correct API request construction through parameter filter inspection
  - Test both success and error scenarios
  - Validate response formatting options
  
  WHAT IS TESTED:
  - Basic prompt processing and response handling
  - Model selection (default vs. specified model validation)
  - Parameter passing (system prompts, temperature, max tokens)
  - Request body construction and API endpoint targeting
  - Response transformation (default text vs. full response objects)
  - Error handling for invalid models and API failures
  
  MOCK STRATEGY:
  - New-MockEnvironment: Provides consistent API configuration
  - Mock Get-AvailableOllamaModels: Controls available model list for validation
  - Mock Invoke-RestMethod: Simulates API responses and allows request inspection
  - New-MockOllamaResponse: Generates realistic API response data
  - Parameter filters: Validate request body JSON structure and API parameters
  
  REQUEST VALIDATION TESTING:
  A key aspect of these tests is validating that the function constructs proper API requests:
  - JSON body structure matches Ollama API expectations
  - Model names are correctly passed through
  - Optional parameters (temperature, tokens) are properly formatted
  - System prompts are included when specified
  
  ERROR HANDLING TESTING:
  The function implements different error handling strategies:
  - Model validation errors return null (uses Write-Error, not throw)
  - API failures re-throw exceptions for caller handling
  - Tests verify both error types behave correctly
  
  This function represents the "goldilocks" complexity level for PowerShell unit testing -
  complex enough to require thorough testing, but simple enough to mock reliably.

.NOTES
  This test module demonstrates effective patterns for testing API wrapper functions:
  - Parameter validation through mock inspection
  - Request construction verification via JSON parsing
  - Dependency isolation through comprehensive mocking
  - Error scenario coverage for both validation and runtime failures
  
  The synchronous, single-request nature of this function makes it much more testable
  than the batch processing or interactive conversation functions.
#>

BeforeAll {
  # Force remove any cached module first
	Get-Module OllamaOpenWebUIAPI | Remove-Module -Force -ErrorAction SilentlyContinue

  $ModulePath = Join-Path $PSScriptRoot "../../OllamaOpenWebUIAPI"
  Import-Module $ModulePath -Force
  . "$PSScriptRoot/../Utils/MockHelpers.ps1"
}

Describe "Invoke-OllamaChat" {
  BeforeEach {
    New-MockEnvironment

    Mock Get-AvailableOllamaModels { 
      return @(
        @{ name = "llama3.2:3b" },
        @{ name = "mistral:latest" }
      )
    } -ModuleName OllamaOpenWebUIAPI
  }

  AfterEach {
    Remove-MockEnvironment
  }

  Context "Basic functionality" {
    BeforeEach {
      $mockResponse = New-MockOllamaResponse -ResponseText "Test response"
      Mock Invoke-RestMethod { return $mockResponse } -ModuleName OllamaOpenWebUIAPI
    }

    It "Should send prompt and return response" {
      $result = Invoke-OllamaChat "Test prompt" 

      $result | Should -Be "Test response"
    }

    It "Should use default model when none specified" {
      Invoke-OllamaChat "Test prompt"

      Assert-MockCommandInModule Invoke-RestMethod -ParameterFilter {
        ($Body | ConvertFrom-Json).model -eq "llama3.2:3b"
      }
    }

    It "Should use specified model" {
      Invoke-OllamaChat "Test prompt" -Model "mistral:latest"

      Assert-MockCommandInModule Invoke-RestMethod -ParameterFilter {
        ($Body | ConvertFrom-Json).model -eq "mistral:latest"
      }
    }

    It "Should include system prompt" {
      Invoke-OllamaChat "Test prompt" -SystemPrompt "Custom system prompt"

      Assert-MockCommandInModule Invoke-RestMethod -ParameterFilter {
        ($Body | ConvertFrom-Json).system -eq "Custom system prompt"
      }
    }

    It "Should return full response when requested" {
      $result = Invoke-OllamaChat "Test prompt" -ReturnFullResponse

      $result.response | Should -Be "Test response"
      $result.model | Should -Be "llama3.2:3b"
    }
  }

  Context "Parameter validation" {
    It "Should reject invalid model" {
      Mock Get-AvailableOllamaModels { 
        return @(@{ name = "llama3.2:3b" })
      } -ModuleName OllamaOpenWebUIAPI
      
      $result = Invoke-OllamaChat "Test" -Model "nonexistent:model" -ErrorAction SilentlyContinue
      $result | Should -BeNullOrEmpty
    }

    It "Should handle temperature parameter" {
      $mockResponse = New-MockOllamaResponse
      Mock Invoke-RestMethod { return $mockResponse }  -ModuleName OllamaOpenWebUIAPI

      Invoke-OllamaChat "Test" -Temperature 0.7

      Assert-MockCommandInModule Invoke-RestMethod -ParameterFilter {
        ($Body | ConvertFrom-Json).options.temperature -eq 0.7
      }
    }

    It "Should handle max tokens parameter" {
      $mockResponse = New-MockOllamaResponse
      Mock Invoke-RestMethod { return $mockResponse } -ModuleName OllamaOpenWebUIAPI

      Invoke-OllamaChat "Test" -MaxTokens 100

      Assert-MockCommandInModule Invoke-RestMethod -ParameterFilter {
        ($Body | ConvertFrom-Json).options.num_predict -eq 100
      }
    }
  }
  
  Context "Error handling" {
    It "Should handle API errors gracefully" {
      Mock Get-AvailableOllamaModels { 
        return @(@{ name = "llama3.2:3b" })
      } -ModuleName OllamaOpenWebUIAPI
      
      Mock Invoke-RestMethod { throw "API Error" } -ModuleName OllamaOpenWebUIAPI

      { Invoke-OllamaChat "Test prompt" -ErrorAction SilentlyContinue } | Should -Throw "API Error"
    }
  }
}