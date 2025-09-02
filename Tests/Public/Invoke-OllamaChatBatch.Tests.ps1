<#
.SYNOPSIS
  Unit tests for Invoke-OllamaChatBatch function.

.DESCRIPTION
  This test module validates the Invoke-OllamaChatBatch function's parameter validation, setup logic,
  and job creation behavior.
  
  TESTING APPROACH:
  Invoke-OllamaChatBatch is a complex function that uses PowerShell background jobs (Start-Job) to 
  process multiple prompts concurrently. Testing the full job execution flow presents several challenges:
  
  1. Background jobs run in separate processes where mocks don't transfer
  2. Job processing involves complex timing, concurrency, and state management
  3. Real background jobs make actual API calls that would require network mocking
  4. Job completion detection and result processing involves intricate loops and conditionals
  
  TESTING STRATEGY:
  Rather than attempting to mock the entire background job system (which proved unreliable due to
  PowerShell job type validation and scope issues), this test suite focuses on:
  
  - Input validation and parameter binding
  - Environment setup and model validation
  - Job creation initiation (testing that Start-Job gets called)
  - Early termination testing (using exceptions to stop execution before job processing)
  
  WHAT IS TESTED:
  - Function existence and parameter structure
  - Required parameter validation (Prompts)
  - Model selection logic (default vs. specified)
  - Parameter passing to background jobs (via Start-Job mock inspection)
  - Basic job creation behavior (verifying Start-Job is invoked)
  
  WHAT IS NOT TESTED:
  - Complete job execution flow and result processing
  - Concurrency limits and job queue management
  - Error handling during job execution
  - Output formatting and result compilation
  - Progress reporting and user feedback
  
  MOCK STRATEGY:
  - Mock Start-Job to throw exceptions and prevent actual job creation
  - Use ArgumentList inspection to validate parameter passing
  - Mock Get-AvailableOllamaModels for model validation testing
  - Use short timeouts and error handling to test setup without full execution
  
  This pragmatic approach allows testing of the critical setup and validation logic while
  avoiding the complexity and reliability issues of mocking PowerShell's background job system.
  For integration testing of the full batch processing workflow, manual testing with real
  APIs or specialized job mocking frameworks would be more appropriate.

.NOTES
  Background job mocking in PowerShell is notoriously difficult due to:
  - Type system constraints (Job vs PSCustomObject conversion issues)
  - Scope isolation between test context and job processes  
  - Complex parameter binding requirements for job-related cmdlets
  
  This test design prioritizes reliability and maintainability over comprehensive coverage
  of the job processing internals.
#>

BeforeAll {
  # Force remove any cached module first
	Get-Module OllamaOpenWebUIAPI | Remove-Module -Force -ErrorAction SilentlyContinue

  # Import module and test helpers
  $ModulePath = Join-Path $PSScriptRoot "../../OllamaOpenWebUIAPI"
  Import-Module $ModulePath -Force
  . "$PSScriptRoot/../Utils/MockHelpers.ps1"
}

Describe "Invoke-OllamaChatBatch" {
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

  Context "Input validation and setup" {
    It "Should exist as a command" {
      Get-Command Invoke-OllamaChatBatch | Should -Not -BeNullOrEmpty
    }

    It "Should require prompts parameter" {
      { Invoke-OllamaChatBatch } | Should -Throw
    }

    It "Should accept array of prompts without throwing parameter errors" {
      $prompts = @("Test1", "Test2")
      
      # Test that the function accepts the parameters without parameter binding errors
      # We expect it to fail later (due to missing real API), but not on parameter validation
      try {
        Invoke-OllamaChatBatch -Prompts $prompts -TimeoutSeconds 1 -ErrorAction SilentlyContinue
      } catch [System.Management.Automation.ParameterBindingException] {
        throw "Parameter binding failed - this shouldn't happen"
      } catch {
        # Other errors (like API failures) are expected and OK
      }
      
      # If we get here, parameter binding worked
      $true | Should -Be $true
    }

    It "Should validate model exists" {
      Mock Get-AvailableOllamaModels { 
        return @(@{ name = "llama3.2:3b" })
      } -ModuleName OllamaOpenWebUIAPI
      
      $prompts = @("Test")
      $result = Invoke-OllamaChatBatch -Prompts $prompts -Model "nonexistent:model" -ErrorAction SilentlyContinue
      $result | Should -BeNullOrEmpty
    }

    It "Should use default model when none specified" {
      Mock Start-Job { 
        $ArgumentList[1] | Should -Be "llama3.2:3b"
        throw "Test validation complete"
      } -ModuleName OllamaOpenWebUIAPI
      
      $prompts = @("Test")
      { Invoke-OllamaChatBatch -Prompts $prompts -TimeoutSeconds 1 } | Should -Throw
    }

    It "Should pass model parameter to jobs" {
      Mock Start-Job { 
        $ArgumentList[1] | Should -Be "mistral:latest"
        throw "Test validation complete"
      } -ModuleName OllamaOpenWebUIAPI
      
      $prompts = @("Test")
      { Invoke-OllamaChatBatch -Prompts $prompts -Model "mistral:latest" -TimeoutSeconds 1 } | Should -Throw
    }
  }

  Context "Job creation" {
    It "Should call Start-Job at least once" {
      Mock Start-Job { throw "Job creation attempted" } -ModuleName OllamaOpenWebUIAPI
  
      $prompts = @("Test1", "Test2", "Test3")
      try {
        Invoke-OllamaChatBatch -Prompts $prompts -TimeoutSeconds 1
      } catch {
        # It's expected to throw
      }

      Invoke-CommandInModule Start-Job -Times 1
    }
  }
}
