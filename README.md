# Goal Prompt
Below is a list of tools I want to set up on my Windows 11 Pro host.

The WSL2 backend is installed and working with Ubuntu 24.04 as the default distro.
The Cursor, Claude Desktop, and Intellij IDEs are installed. This host is running an up-to-date version of Windows 11 Pro.

Please develop me a step-by-step implementation plan for performing the necessary installation, configuration, and verification steps to achieve my target development environment.
Generate the plan as a Github-flavoured markdown file.
The plan should have separate sections for each tool with their own installation, configuration and verification steps.
The plan should have numbered (sub)sections and paragraphs to allow for easy reference.
The plan should have a final "tracking" section which allows one to later record which steps have not been started, are awaiting installation, awaiting configuration, awaiting verification, have succeeded, or have failed.
Use local page links to redirect the user from the step instructions to the tracking section and vice-versa.
Common dependencies should be factored into a separate section and set-up as early in the plan as is practical.
Installation instruction should leverage tooling native to Ubuntu 24.04 where possible e.g. using "apt" as a package manager.
If multiple package managers are required then please minimise the number where possible e.g. one for NodeJS package, one for Python etc.
Each tool should have independent verification steps for each for each IDE & interface e.g. confirm the GitHub MCP Server is working from Cursor and Claude Desktop, should they be the only two IDEs/Interfaces.
Where a verification is possible via a CLI command from a bash shell then include that as the first verification step.

If there is an opportunity for me to bootstrap the implementation before handing over to you to complete it, for example by giving you (Claude Desktop) access to the backend shell via an MCP Server, then incorporate that into the plan.


To test the approach, please generate the plan cut down to the Claude Desktop and Cursor IDEs for the GitHub MCP server.

# Backends
1. Ubuntu 24.04 on WSL2

# IDEs & Interfaces
1. Claude Code
2. Cursor (with WSL backend)
3. Claude Desktop (with WSL backend)
4. Intellij (with WSL backend)

# MCP Servers for all IDEs
Where possible, the MCP server should be run locally.

1. https://github.com/github/github-mcp-server
2. [oraios/serena](https://github.com/oraios/serena)
3. https://github.com/nickclyde/duckduckgo-mcp-server
4. All reference MCP servers from https://github.com/modelcontextprotocol/servers/tree/main
5. https://github.com/alioshr/memory-bank-mcp
6. https://github.com/tumf/mcp-shell-server
7. https://github.com/wonderwhy-er/DesktopCommanderMCP
8. https://github.com/liuyoshio/mcp-compass
9. [juehang/vscode-mcp-server ](https://github.com/juehang/vscode-mcp-server) (with Cursor as the target "VSCode" instance. Requires an extension be installed in VSCode/Cursor first.)
10. https://github.com/kocierik/mcp-nomad
11. https://github.com/hashicorp/terraform-mcp-server
12. https://github.com/hloiseaufcms/mcp-gopls
13. https://github.com/isaacphi/mcp-language-server
14. https://github.com/JetBrains/mcp-jetbrains
15. https://github.com/biegehydra/BifrostMCP
16. https://github.com/yikakia/godoc-mcp-server
17. https://github.com/BurtTheCoder/mcp-shodan
18. https://github.com/fr0gger/MCP_Security
19. https://github.com/roadwy/cve-search_mcp
20. https://github.com/smithery-ai/mcp-obsidian
21. https://github.com/upstash/context7
22. https://github.com/quillopy/quillopy-mcp

# Extensions for Cursor
1. https://github.com/Pythagora-io/gpt-pilot2. 
