---
applyTo: "**"
description: "Prefer Serena for semantic operations and GitHub Copilot Chat extension for syntactic ones."
---
Your MUST prefer to use tools that operate on the semantic structure of the code (e.g. finding symbols, modifying classes or functions) over tools that perform text manipulation.

Most of the code manipulation tools you have access to are provided by the Serena MCP server ("Serena") or the GitHub Copilot Chat extension ("GitHub"). You SHOULD prefer to use the first tool in each pair to the second in the list below.
* get_symbols_overview (Serena) over read_project_structure (GitHub)
* find_symbol (Serena) over search_workspace_symbols (GitHub)
* find_referencing_symbols (Serena) over list_code_usages (GitHub)
* replace_symbol_body (Serena) over insert_edit_into_file (GitHub)
* insert_after_symbol (Serena) over insert_edit_into_file (GitHub)
* insert_before_symbol (Serena) over insert_edit_into_file (GitHub)
* delete_symbol (Serena) over insert_edit_into_file (GitHub)
* read_file (GitHub) over read_file (Serena).
* create_file (GitHub) over create_text_file (Serena).
* list_dir (GitHub) over list_dir (Serena).
* file_search (GitHub) over find_file (Serena).
* grep_search (GitHub) over search_for_pattern (Serena).
* execute_shell_command (Serena) over run_in_terminal (GitHub).