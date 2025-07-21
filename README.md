# Ollama OpenWebUI PowerShell API

> [!NOTE]
> The basis of this knowledge is [my previous project for local LLM](https://github.com/adjiap/local_ollama_powershell_setup). In general, it should work with any OpenWebUI-based on-premise LLM.

<!-- TABLE OF CONTENTS -->
## Table of Contents
<ol>
  <li>
    <a href="#about-the-project">About The Project</a>
  </li>
  <li>
    <a href="#getting-started">Getting Started</a>
    <ul>
      <li><a href="#environment-setup">Environment Setup</a></li>
      <li><a href="#import-module">Import-Module</a></li>
      <li><a href="#persistent-install">Persistent Installation</a></li>
    </ul>
  </li>
  <li>
    <a href="#usage">Usage</a>
    <ul>
      <li><a href="#getting-a-list-of-available-ollama-models">Getting a list of available ollama models</li>
      <li><a href="#start-a-conversation-with-ollama-model">Start a conversation with Ollama model</li>
      <li><a href="#sending-a-batch-of-prompts-to-ollama-model">Sending a batch of prompts to Ollama model</li>
    </ul>
  </li>
  <li><a href="#acknowledgements">Acknowledgements</a></li>
  <li><a href="#license">License</a></li>
</ol>

<!-- ABOUT THE PROJECT -->
## About The Project

This project is an extension of the local RAG LLM that I had built in my previous [GitHub project](https://github.com/adjiap/local_ollama_powershell_setup). It attempts to create an API for direct usage of the Ollama LLM, via OpenWebUI's interface in Windows [Terminal](https://github.com/microsoft/terminal) (ideally through [PowerShell Core](https://github.com/PowerShell/PowerShell))

<!-- GETTING STARTED -->
## Getting Started
You first need to get the API Key for your account. You can get it in Settings -> Account -> API Key
<img width="450" height="290" alt="image" src="https://github.com/user-attachments/assets/31c4fda3-49bd-4420-8148-5c1718cc61f6" />


### Environment Setup

Required environment variables:
- `OPENWEBUI_URL`: Base URL for OpenWebUI (with OpenWebUI, it would be by default `http://localhost:3000`)
- `OPENWEBUI_API_KEY`: API authentication key
- `OLLAMA_API_CHAT`: Chat endpoint path 
- `OLLAMA_API_SINGLE_RESPONSE`: Generate endpoint path
- `OLLAMA_API_TAGS`: Tags endpoint path

> [!NOTE]
> I deliberately not hardcode the API, and having it from the `.env`, because I'd like to have it modular, in case Ollama changes its API (unlikely, but still).
> Moreover, you can change it to OpenAI's API if you don't use Ollama. Maybe in the future I'd update the module to also have OpenAI's API, but for now, I'm going to stick with only Ollama API.

Have the variables above imported in your environment. Here's a sample `.env` for you to copy to get you started.

```txt
# .env
OPENWEBUI_URL="http://localhost:3000/"
OPENWEBUI_API_KEY="<Insert API Key here>" # e.g. sk-89jf98jfkasjdfaksd89jkfljalk
OLLAMA_API_SINGLE_RESPONSE="ollama/api/generate"
OLLAMA_API_CHAT="ollama/api/chat"
OLLAMA_API_TAGS="ollama/api/tags"
```

Then, there are two recommended ways for you to import the modules, via <a href="#import-module">Import-Module</a> or via <a href="#persistent-install">Persistent Installation</a>

### Import-Module
> [!TIP]
> Use `Import-Module` for development and testing, in case you want to tweak things in the script.

```powershell
Import-Module "C:\path\to\repos\local_ollama_powershell_wrapper_api\OllamaOpenWebUIAPI\OllamaOpenWebUIAPI.psd1"
```

### Persistent Install
> [!TIP]
> Use the persistent install for "everyday use", so you don't need to install it every time you need it.

```powershell
$P7UserModulePath = Join-Path $env:UserProfile "Documents\PowerShell\Modules"
$P5UserModuelPath = Join-Path $env:UserProfile "Documents\WindowsPowerShell\Modules"

Copy-Item -Path ".\OllamaOpenWebUIAPI" -Destination "$P7UserModulePath\" -Recurse
Copy-Item -Path ".\OllamaOpenWebUIAPI" -Destination "$P5UserModulePath\" -Recurse

# Finally, copy the following line, to your powershell (5/7) profile
Add-Content -Path $PROFILE -Value "Import-Module OllamaOpenWebUIAPI"
```

<!-- USAGE EXAMPLES -->
## Usage
You can get a list of all the commands available in the module by running the following:

```powershell
Get-Command -Module OllamaOpenWebUIAPI
<#
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Function        Get-AvailableOllamaModels                          0.0.1      OllamaOpenWebUIAPI
Function        Invoke-OllamaChat                                  0.0.1      OllamaOpenWebUIAPI
Function        Invoke-OllamaChatBatch                             0.0.1      OllamaOpenWebUIAPI
Function        Start-OllamaChatConversation                       0.0.1      OllamaOpenWebUIAPI
#>
```

> [!TIP]
> If you'd like some examples, I've added it in the docstrings, and you can call it with `Get-Help Start-OllamaChatConversation -Examples` or other functions if you need to

### Getting a list of available ollama models

```powershell
# This will show all the available models for you (your API key)
Get-AvailableOllamaModels
<#
mistral:latest
codellama:latest
llama3.2:latest
llama3.1:latest
#>
```

### Start a conversation with Ollama model

```powershell
Start-OllamaConversationChat
<#
Fetching available models...
Available models:
    - mistral:latest
    - codellama:latest
    - llama3.2:latest
    - llama3.1:latest

Chat with llama3.2:latest
Available commands: exit, quit, clear, save, count, model, set-system

You: How far is the sun from the earth?

Assistant: Approximately 93 million miles (149.6 million kilometers).

You: ...
#>
```

### Sending a batch of prompts to Ollama model

```powershell
$questions = @(
  "What is DevSecOps?",
  "How do I secure Docker containers?",
  "What is shift-left security?"
)

Invoke-OllamaChatBatch -Prompts $questions
<#
Batch processing completed in 2.9036188 seconds
Successfully processed: 3/3

1. What is DevSecOps?
   > DevSecOps is an approach to software development that integrates security into every stage of the process, from development to deployment. It aims to ensure secure coding practices and continuous monitoring throughout the development cycle.

2. How do I secure Docker containers?
   > Here are some ways to secure Docker containers:

1. **Set a strong password**: Use a strong, unique password for the Docker daemon.
2. **Use a registry**: Store images in a trusted registry like Docker Hub or a private registry.
3. **Limit privileges**: Run containers with limited privileges using `docker run --privileged=false`.
4. **Use AppArmor or SELinux**: Apply security constraints to containers using AppArmor or SELinux.
5. **Regularly update and patch**: Keep the Docker engine, containers, and base images up-to-date.
6. **Monitor and log**: Enable logging and monitoring to detect suspicious activity.
7. **Use network policies**: Define network access control lists (ACLs) for incoming and outgoing traffic.
8. **Disable unnecessary services**: Stop unnecessary services in running containers.
9. **Use a Secure Filesystem**: Use a secure filesystem like UnionFS oraufFS.
10. **Implement IAM (Identity and Access Management)**: Manage user identities and permissions.

3. What is shift-left security?
   > Shift-left security refers to applying security principles and controls earlier in the software development lifecycle.
#>
```

## Acknowledgements
* [Ollama](https://github.com/ollama/ollama)
* [Open WebUI](https://github.com/open-webui/open-webui)

<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.txt` for more information.
