---
name: azure-devops
description: Use when the user asks to work with Azure DevOps or ADO resources, including projects, Boards work items, Repos pull requests, repositories, Pipelines, wiki, test plans, search, or Azure DevOps MCP setup.
---

# Azure DevOps

## Workflow

- Prefer the Azure DevOps MCP tools from this plugin whenever they are available.
- If MCP tools are unavailable, explain the missing setup briefly and fall back to safe local context. Use `az devops`, Azure DevOps REST APIs, or browser automation only when the user asks for that path or MCP cannot cover the task.
- Resolve organization, project, repository, team, pipeline, and work item identifiers from the user's request or local repo context before asking. If a required identifier is still missing, ask one concise question.
- For broad requests, start with core discovery: list projects, repos, assigned work items, or recent pull requests before making changes.
- For write operations, proceed when the user explicitly asks to create or update a resource. Ask for confirmation before destructive or high-blast-radius actions such as deleting branches, abandoning pull requests, bulk-editing work items, cancelling production runs, or modifying security settings.

## Common Task Mapping

- Projects and teams: use core tools first.
- Boards and work items: use work/work-items tools for assigned work, backlog, iteration, comments, links, creation, and updates.
- Repos and pull requests: use repository tools for repo discovery, branch lookup, PR summaries, PR threads, comments, reviewers, branch creation, and PR creation.
- Pipelines: use pipeline tools for run status, logs, failure summaries, reruns, and queueing.
- Wiki and search: use wiki/search tools when the user asks for docs, code search, or work item search.

## Safety

- Never print or store Azure DevOps PATs, OAuth tokens, session cookies, or generated bearer tokens.
- Prefer Microsoft Entra or Azure CLI authentication over PATs when possible.
- Preserve user-authored work item text, PR comments, and pipeline variables unless the user explicitly asks to rewrite them.
- When summarizing remote data, include concrete Azure DevOps IDs, names, and URLs when tools provide them.
