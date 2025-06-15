Expert Bot Guide: Extending Roocode with Custom Modes

This guide provides foundational knowledge for creating an expert bot focused on extending Roocode's functionality through custom modes. It addresses the structure of custom modes, their storage within the .roo/ folder (or equivalent), and clarifies their scope (global vs. project-specific).

1. Understanding Roocode Custom Modes

Roocode's custom modes enable developers to define specialized "personalities" or behaviors for the underlying Large Language Model (LLM) agent. Each mode customizes how the LLM interacts with your codebase, allowing for fine-grained control over its tasks.

Key Aspects of Custom Modes:
Role Definition: Each mode is given a description of the LLM's personality and purpose.
LLM Model & Instructions: You can specify the LLM model to be used for a particular mode and provide custom instructions or guidelines the mode should follow.
Tool Permissions: Modes can be configured with specific tool groups (e.g., read, edit, browser, command, mcp) to control what actions the AI agent can perform.
Configuration Format: While historically JSON, newer versions of Roocode (e.g., v3.19) now support YAML for defining custom modes, offering cleaner configuration.

2. Global vs. Project-Specific Custom Modes

Roocode offers flexibility in where your custom modes are defined, impacting their scope:

Global Custom Modes:
Location: Global custom modes are configured within your Roo Code VS Code extension settings. These settings apply across all your VS Code workspaces and projects where Roocode is active.
Management: They are managed directly through the Roo Code configuration interface (often found via the settings gear icon in the Roo Code sidebar) or by manually editing the relevant VS Code settings JSON file.
Use Case: Ideal for common workflows or agent personalities you use frequently across various coding projects (e.g., a "Documentation Generator" mode or a "Refactor Helper" mode).

Project-Specific Custom Modes:
Location: Project-specific modes can be defined in a .roomodes file located at the root of your project directory.
Mode-Specific Rules: Additionally, you can define very granular, mode-specific instructions within a .roo/rules-{modeSlug}/ directory at your project root. Markdown files placed within this directory provide instructions specific to the {modeSlug}.
Git Integration: Since these files and folders (.roomodes, .roo/) reside within the project directory, they are typically included in version control. If you intend for them to be specific to your local setup and not shared with others, you should include .roomodes and the .roo/ directory in your project's .gitignore file.
Use Case: Perfect for workflows or agent behaviors tailored to a particular project's unique requirements, coding standards, or architectural patterns.

3. The .roo/ Folder and its Purpose

The .roo/ folder is a special directory located at the root of your project that serves as a container for project-specific configurations related to Roocode, particularly for custom mode instructions.

Structure: Inside .roo/, you can create subdirectories named rules-{modeSlug}/ (e.g., .roo/rules-my-custom-mode/).
Content: Markdown files placed within these rules-{modeSlug}/ directories contain additional custom instructions that the corresponding modeSlug will respect when active. This allows for highly contextual and project-aware mode behavior.
Context Management: Roocode uses these files to build the overall system prompt for the AI agent, combining global settings, mode definitions, and these project-specific rules.

4. Building Your Expert Bot for Roocode Custom Modes

To become an expert bot on extending Roocode with custom modes, you must leverage the understanding of their definition, scope, and the role of the .roo/ folder.

Key Capabilities of the Expert Bot:
Mode Definition Guidance: Explain how to define new custom modes, specifying their slug, name, roleDefinition, toolPermissions, and customInstructions in YAML format.
Scope Recommendation: Advise users on whether a mode should be global or project-specific based on their use case.
.roo/ Folder Usage: Guide users on creating and populating the .roo/rules-{modeSlug}/ directories for project-specific instructions.
Git Ignore Advice: Recommend including .roomodes and .roo/ in .gitignore if project-specific configurations are not intended for team-wide version control.
Troubleshooting: Provide insights into common issues, such as ensuring correct YAML syntax or understanding how global and local instructions combine.
Best Practices: Suggest patterns for effective mode design (e.g., focusing each mode on a single, clear purpose).

Conclusion & Next Steps

Roocode's custom modes offer powerful extensibility, allowing for highly tailored AI assistance. By understanding the distinction between global and project-specific modes and the function of the .roo/ folder, you can effectively define custom behaviors.

To further enhance your expert bot, consider:
Providing concrete YAML examples for both simple global modes and modes with project-specific .roo/rules integration.
Including guidance on how to programmatically interact with Roocode's mode switching (if API allows) for advanced automation scenarios.
Detailing the exact structure of the settings.json file where global modes are stored
