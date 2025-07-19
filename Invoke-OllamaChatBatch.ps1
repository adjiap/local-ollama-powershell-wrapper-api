function Invoke-OllamaChatBatch {
	<#
	.SYNOPSIS
		Processes multiple prompts in parallel using Ollama models through OpenWebUI.

	.DESCRIPTION
		The Invoke-OllamaChatBatch function sends multiple prompts to Ollama models concurrently
		using PowerShell background jobs, significantly reducing total processing time compared
		to sequential processing. It maintains order of results and provides comprehensive
		error handling and progress reporting.

		This function is ideal for bulk operations such as code reviews, documentation generation,
		security analysis, or testing multiple variations of prompts. It efficiently utilizes
		GPU resources while being respectful of other users on the system.

	.PARAMETER Prompts
		Array of prompts to process. Each prompt will be sent as a separate request to the model.
		This parameter is mandatory and accepts string arrays from pipeline input.

	.PARAMETER Model
		The Ollama model to use for all prompts. Must be one of the available models.
		Default: "llama3.2:latest"

		Available models:
		- llama3.2:latest    - Fast, efficient for general tasks and quick responses
		- llama3.1:latest    - Balanced performance, good for complex reasoning and detailed responses  
		- mistral:latest     - Excellent for creative writing, analysis, and instruction following
		- codellama:latest   - Specialized for code generation, debugging, and programming tasks

	.PARAMETER SystemPrompt
		System prompt to set the behavior and context for all requests. This helps ensure
		consistent response style across the batch.
		Default: "Only give short answers, with what is asked for"

	.PARAMETER MaxConcurrentJobs
		Maximum number of requests to process simultaneously. Higher values may process faster
		but can overwhelm the system or interfere with other users. Consider your team's usage
		patterns when setting this value.
		Default: 3
		Range: 1-10 (recommended: 2-5 for team environments)

	.PARAMETER TimeoutSeconds
		Timeout in seconds for each individual request. Requests that exceed this time will
		be marked as failed and processing will continue with remaining requests.
		Default: 300 (5 minutes)

	.PARAMETER ShowProgress
		Displays a progress bar showing completion status during batch processing.
		Useful for long-running batches to monitor progress.

	.PARAMETER ContinueOnError
		If specified, continues processing remaining prompts even if some requests fail.
		Without this switch, the function stops on the first error.
		Recommended for large batches where some failures are acceptable.

	.PARAMETER ReturnFullResponse
		If specified, returns the complete response objects with all metadata.
		Default: Returns formatted output with prompts and answers.

	.PARAMETER RemovePromptInAnswer
		If specified, returns only the answers without the prompts.
		Only works when ReturnFullResponse is not used.
	
	.INPUTS
		String[]. You can pipe an array of strings to Invoke-OllamaChatBatch.

	.OUTPUTS
		PSCustomObject[]. Returns an array of objects with the following properties:
		- Index: Original position in the input array
		- Prompt: The original prompt text
		- Model: Model used for processing
		- Success: Boolean indicating if the request succeeded
		- Response: Generated response text (null if failed)
		- Error: Error message (null if successful)
		- StartTime: When the request started
		- EndTime: When the request completed
		- Duration: TimeSpan showing how long the request took

	.EXAMPLE
		$questions = @(
			"What is DevSecOps?",
			"How do I secure Docker containers?",
			"What is shift-left security?"
		)
		$results = Invoke-OllamaChatBatch -Prompts $questions
		
		Processes three security-related questions using the default model (llama3.2:3b)
		with default concurrency settings.

	.EXAMPLE
		$codePrompts = @(
			"Write a Python function to validate email addresses",
			"Create a bash script to backup databases",
			"Write a PowerShell function to test network connectivity"
		)
		$results = Invoke-OllamaChatBatch -Prompts $codePrompts -Model "codellama:7b" -MaxConcurrentJobs 2 -ShowProgress
		
		Processes code generation prompts using the specialized CodeLlama model with limited
		concurrency and progress display.

	.EXAMPLE
		Get-ChildItem *.py | ForEach-Object { 
			"Review this Python code for security issues: $(Get-Content $_.FullName -Raw)" 
		} | Invoke-OllamaChatBatch -Model "codellama:7b" -SystemPrompt "You are a security code reviewer" -ContinueOnError
		
		Reviews all Python files in the current directory for security issues, continuing
		even if some files fail to process.

	.EXAMPLE
		$functions = @("CreateUser", "DeleteUser", "UpdateUser", "GetUser")
		$docPrompts = $functions | ForEach-Object { 
			"Write comprehensive API documentation for the function: $_. Include parameters, return values, and examples." 
		}
		
		$docs = Invoke-OllamaChatBatch -Prompts $docPrompts -Model "mistral:7b" -SystemPrompt "You are a technical writer" -MaxConcurrentJobs 2 -ShowProgress -Verbose
		
		$docs | ForEach-Object {
			"$($functions[$_.Index])_docs.md" | Set-Content -Value $_.Response
		}
		
		Generates API documentation for multiple functions and saves each to a separate file.

	.EXAMPLE
		# Performance comparison between batch and sequential processing
		$questions = @("What is AI?") * 10  # 10 identical questions
		
		# Sequential processing
		$sequential = Measure-Command {
			$questions | ForEach-Object { Invoke-OllamaChat $_ }
		}
		
		# Batch processing  
		$batch = Measure-Command {
			Invoke-OllamaChatBatch -Prompts $questions -MaxConcurrentJobs 5
		}
		
		Write-Host "Sequential: $($sequential.TotalSeconds) seconds"
		Write-Host "Batch: $($batch.TotalSeconds) seconds"
		Write-Host "Speedup: $([math]::Round($sequential.TotalSeconds / $batch.TotalSeconds, 2))x"
		
		Demonstrates the performance benefits of batch processing.

	.NOTES
		Prerequisites:
		- OPENWEBUI_API_KEY environment variable must be set
		- OPENWEBUI_URL environment variable must be set  
		- OLLAMA_API_SINGLE_RESPONSE environment variable must be set
		- Network access to OpenWebUI instance
		
		Performance Considerations:
		- Higher MaxConcurrentJobs values can improve speed but may overwhelm the system
		- Consider other users when setting concurrency in team environments
		- GPU memory limits may affect how many requests can be processed simultaneously
		- Large prompts or responses may require longer timeout values
		
		Multi-User Considerations:
		- Requests are queued in OpenWebUI and processed sequentially by Ollama
		- Your batch requests will be mixed with other users' requests in the queue
		- Consider using lower concurrency (2-3) in busy team environments
		- Monitor system resources to avoid impacting other users
		
		Error Handling:
		- Individual request failures don't stop the entire batch (with -ContinueOnError)
		- Network timeouts are handled gracefully
		- Failed requests include error details in the Error property
		- All background jobs are properly cleaned up regardless of success/failure

	.LINK
		Invoke-OllamaChat
		Start-OllamaChatConversation

	.FUNCTIONALITY
		This function provides efficient bulk processing of prompts using Ollama models,
		with comprehensive error handling, progress reporting, and multi-user awareness.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[string[]]$Prompts,
		
		[Parameter(Mandatory=$false)]
		[ValidateSet(
			"llama3.2:latest",
			"llama3.1:latest",
			"mistral:latest",
			"codellama:latest"
		)]
		[string]$Model = "llama3.2:latest",
		
		[Parameter(Mandatory=$false)]
		[string]$SystemPrompt = "Only give short answers, with what is asked for",
		
		[Parameter(Mandatory=$false)]
		[ValidateRange(1, 10)]
		[int]$MaxConcurrentJobs = 3,
		
		[Parameter(Mandatory=$false)]
		[int]$TimeoutSeconds = 300,
		
		[Parameter(Mandatory=$false)]
		[switch]$ShowProgress,
		
		[Parameter(Mandatory=$false)]
		[switch]$ContinueOnError,
		
		[Parameter(Mandatory=$false)]
		[switch]$ReturnFullResponse,
		
		[Parameter(Mandatory=$false)]
		[switch]$RemovePromptInAnswer
	)
	
	begin {
		#region Check Environment Variables
		$requiredEnvVars = @(
			'OPENWEBUI_API_KEY',
			'OPENWEBUI_URL',
			'OLLAMA_API_SINGLE_RESPONSE',
			'OLLAMA_API_TAGS'
		)
		$missingVars = @()

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

		#region Instantiate variables
		$results = @()
		$jobs = @()
		$startTime = Get-Date
		$promptIndex = 0
		#endregion
	}
	
	process {    
		# Exits in case any of the checks in begin{} fails
		if ($abort) {
			return $null
		}

		Write-Verbose "Starting batch processing of $($Prompts.Count) prompts with model: $Model"
		Write-Verbose "Max concurrent jobs: $MaxConcurrentJobs"
		while ($promptIndex -lt $Prompts.Count -or $jobs.Count -gt 0) {
				
			# Start new jobs up to the limit
			while ($jobs.Count -lt $MaxConcurrentJobs -and $promptIndex -lt $Prompts.Count) {
				$currentPrompt = $Prompts[$promptIndex]
				$currentIndex = $promptIndex

				$jobArgs = @(
					$currentPrompt
					$Model
					$SystemPrompt
					$env:OPENWEBUI_API_KEY
					$env:OPENWEBUI_URL
					$env:OLLAMA_API_SINGLE_RESPONSE
					$TimeoutSeconds
				)

				Write-Verbose "Starting job $($currentIndex + 1)/$($Prompts.Count): $($currentPrompt.Substring(0, [Math]::Min(50, $currentPrompt.Length)))..."
				
				$job = Start-Job -ScriptBlock {
					param($Prompt, $Model, $SystemPrompt, $ApiKey, $BaseUrl, $SingleResponseEndpoint, $TimeoutSeconds)
					
					try {
						# Build request
						$headers = @{
							"Authorization" = "Bearer $ApiKey"
							"Content-Type" = "application/json"
						}
						
						$body = @{
							model = $Model
							system = $SystemPrompt
							prompt = $Prompt
							stream = $false
						}
		
						$jsonBody = $body | ConvertTo-Json -Depth 10
						$uri = "$BaseUrl$SingleResponseEndpoint"

						$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $jsonBody -TimeoutSec $TimeoutSeconds
						
						return @{
							Success = $true
							Response = $response.response
							Model = $response.model
							Duration = $response.total_duration
							Error = $null
						}
					} catch {
							return @{
								Success = $false
								Response = $null
								Model = $Model
								Duration = $null
								Error = $_.Exception.Message
							}
					}
				} -ArgumentList $jobArgs
				
				$jobs += @{
					Job = $job
					Index = $currentIndex
					Prompt = $currentPrompt
					StartTime = Get-Date
				}
				
				$promptIndex++
			}
			
			# Wait for at least one job to complete
			if ($jobs.Count -gt 0) {
				do {
					Start-Sleep -Milliseconds 200
					
					$completedJobs = $jobs | Where-Object { $_.Job.State -eq "Completed" -or $_.Job.State -eq "Failed" }
					
					if ($ShowProgress) {
						$totalCompleted = $results.Count + $completedJobs.Count
						$percentComplete = [Math]::Round(($totalCompleted / $Prompts.Count) * 100, 1)

						# Additional safety check to prevent percentage > 100
						$percentComplete = [Math]::Min($percentComplete, 100)
						
						Write-Progress -Activity "Processing prompts" -Status "$totalCompleted/$($Prompts.Count) completed" -PercentComplete $percentComplete
					}
				} while ($completedJobs.Count -eq 0)
				
				# Process completed jobs
				foreach ($completedJob in $completedJobs) {
					try {
						$jobResult = Receive-Job -Job $completedJob.Job
						
						$result = [PSCustomObject]@{
							Index = $completedJob.Index
							Prompt = $completedJob.Prompt
							Model = $Model
							Success = $jobResult.Success
							Response = $jobResult.Response
							Error = $jobResult.Error
							StartTime = $completedJob.StartTime
							EndTime = Get-Date
							Duration = (Get-Date) - $completedJob.StartTime
						}
						
						$results += $result
						
						if ($result.Success) {
							Write-Verbose "✓ Job $($result.Index + 1) completed successfully"
						} else {
							Write-Warning "✗ Job $($result.Index + 1) failed: $($result.Error)"
							if (-not $ContinueOnError) {
									throw "Job failed: $($result.Error)"
							}
						}
					} catch {
						Write-Error "Error processing job $($completedJob.Index + 1): $($_.Exception.Message)"
						if (-not $ContinueOnError) {
							throw
						}
					} finally {
						Remove-Job -Job $completedJob.Job -Force
					}
				}
					
				# Remove completed jobs from tracking
				$jobs = $jobs | Where-Object { $_.Job.State -ne "Completed" -and $_.Job.State -ne "Failed" }
			}
		}
		if ($ShowProgress) {
			Write-Progress -Activity "Processing prompts" -Completed
		}
	}
	
	end {
		$endTime = Get-Date
		$totalDuration = $endTime - $startTime
		$successCount = ($results | Where-Object Success).Count
		
		Write-Host "Batch processing completed in $($totalDuration.TotalSeconds) seconds" -ForegroundColor Green
		Write-Host "Successfully processed: $successCount/$($results.Count)" -ForegroundColor $(if ($successCount -eq $results.Count) { "Green" } else { "Yellow" })
		
		# Sort results by original index to maintain order
		$sortedResults = $results | Sort-Object Index
		
		# Return based on flags
		if ($ReturnFullResponse) {
			return $sortedResults
		} elseif ($RemovePromptInAnswer) {
			# Return only the answers
			Write-Host ""
			$sortedResults | ForEach-Object {
				if ($_.Success) {
					Write-Host "$($_.Index + 1). $($_.Response)" -ForegroundColor White
				} else {
					Write-Host "$($_.Index + 1). [ERROR: $($_.Error)]" -ForegroundColor Red
				}
				Write-Host ""
				}
		} else {
			# Default: Return formatted prompt + answer
			Write-Host ""
			$sortedResults | ForEach-Object {
				if ($_.Success) {
					Write-Host "$($_.Index + 1). $($_.Prompt)" -ForegroundColor Cyan
					Write-Host "   > $($_.Response)" -ForegroundColor White
				} else {
					Write-Host "$($_.Index + 1). $($_.Prompt)" -ForegroundColor Cyan
					Write-Host "   > [ERROR: $($_.Error)]" -ForegroundColor Red
				}
				Write-Host ""
			}
		}
	}
}