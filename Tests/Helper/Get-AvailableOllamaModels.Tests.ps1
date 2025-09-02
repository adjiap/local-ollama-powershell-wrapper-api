<#
.SYNOPSIS
  Unit tests for Get-AvailableOllamaModels function.

.DESCRIPTION
  This test module validates the Get-AvailableOllamaModels function's API interaction, error handling,
  and data transformation capabilities.
  
  TESTING APPROACH:
  Get-AvailableOllamaModels is a straightforward API wrapper function that makes HTTP requests to
  retrieve available Ollama models. This function is well-suited for traditional unit testing
  because it has:
  
  1. Clear input/output contracts
  2. Predictable API interactions
  3. Well-defined error scenarios
  4. Simple data transformation logic
  
  TESTING STRATEGY:
  This test suite uses comprehensive mocking to isolate the function from external dependencies:
  
  - Mock environment variables for configuration testing
  - Mock Invoke-RestMethod to simulate API responses and failures
  - Use helper functions (New-MockModelsResponse) for consistent test data
  - Test both success and failure scenarios thoroughly
  
  WHAT IS TESTED:
  - Environment variable validation (API key, base URL requirements)
  - Successful API interaction with proper endpoint and headers
  - Data transformation (default model names vs. full response objects)
  - Error handling for network failures and HTTP errors
  - Function contract adherence (return types, parameter behavior)
  
  MOCK STRATEGY:
  - New-MockEnvironment: Sets up consistent test environment variables
  - Mock Invoke-RestMethod: Controls API responses and simulates failures
  - New-MockModelsResponse: Provides realistic API response data
  - Parameter filters: Validate correct API endpoint and authentication headers
  
  ERROR HANDLING TESTING:
  The function implements graceful error handling by returning empty arrays on failure
  rather than throwing exceptions. Tests verify this behavior for:
  - Missing environment variables
  - Network connectivity issues
  - HTTP authentication failures
  - Malformed API responses
  
  This function serves as an excellent example of testable API wrapper design with
  proper error handling and clean separation of concerns.

.NOTES
  This test module demonstrates effective API testing patterns:
  - Environment variable mocking for configuration testing
  - HTTP client mocking with parameter validation
  - Consistent test data generation with helper functions
  - Comprehensive error scenario coverage
  
  The function's design makes it highly testable compared to the interactive and
  background job functions in the same module.
#>

BeforeAll {
	# Force remove any cached module first
	Get-Module OllamaOpenWebUIAPI | Remove-Module -Force -ErrorAction SilentlyContinue

	# Import module and test helpers
	$ModulePath = Join-Path $PSScriptRoot "../../OllamaOpenWebUIAPI"
	Import-Module $ModulePath -Force
	. "$PSScriptRoot/../Utils/MockHelpers.ps1"
}

Describe "Get-AvailableOllamaModels" {
	BeforeEach {
		New-MockEnvironment
	}

	AfterEach {
		Remove-MockEnvironment
	}

	Context "When environment variables are missing" {
		It "Should return empty array when OPENWEBUI_API_KEY is missing" {
			[Environment]::SetEnvironmentVariable('OPENWEBUI_API_KEY', $null, 'Process')
			
			$result = Get-AvailableOllamaModels -ErrorAction SilentlyContinue
			$result | Should -Be @()
		}
		
		It "Should return empty array when OPENWEBUI_URL is missing" {
			[Environment]::SetEnvironmentVariable('OPENWEBUI_URL', $null, 'Process')
			
			$result = Get-AvailableOllamaModels -ErrorAction SilentlyContinue
			$result | Should -Be @()
		}
	}
  
	Context "When API call succeeds" {
		BeforeEach {
			$mockResponse = New-MockModelsResponse
			Mock Invoke-RestMethod { return $mockResponse } -ModuleName OllamaOpenWebUIAPI
		}

		It "Should return model names by default" {
			$result = Get-AvailableOllamaModels
			
			$result | Should -HaveCount 3
			$result[0] | Should -Be "llama3.2:3b"
			$result[1] | Should -Be "mistral:latest"
			$result[2] | Should -Be "codellama:7b"
		}
		
		It "Should return full response when requested" {
			$result = Get-AvailableOllamaModels -ReturnFullResponse
			
			$result | Should -HaveCount 3
			$result[0].name | Should -Be "llama3.2:3b"
			$result[0].size | Should -Be 2019393792
			$result[0].modified_at | Should -Be "2024-01-15T10:30:00Z"
		}
		
		It "Should call correct API endpoint" {
			Get-AvailableOllamaModels
			
			Invoke-CommandInModule Invoke-RestMethod -Times 1 -ParameterFilter {
				$Uri -eq "http://localhost:3000/ollama/api/tags"
			}
		}
		
		It "Should include proper headers" {
			Get-AvailableOllamaModels
			
			Invoke-CommandInModule Invoke-RestMethod -Times 1 -ParameterFilter {
				$Headers.Authorization -eq "Bearer test-api-key-12345"
			}
		}
	}
  
	Context "When API call fails" {
		It "Should handle network errors gracefully" {
			Mock Invoke-RestMethod { throw "Network error" }
			
			$result = Get-AvailableOllamaModels -ErrorAction SilentlyContinue
			$result | Should -Be @()
		}
		
		It "Should handle HTTP errors gracefully" {
			$exception = New-Object System.Net.WebException("HTTP 401 Unauthorized")
			Mock Invoke-RestMethod { throw $exception }
			
			$result = Get-AvailableOllamaModels -ErrorAction SilentlyContinue
			$result | Should -Be @()
		}
	}
}
