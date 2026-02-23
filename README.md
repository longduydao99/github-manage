# Git Management System

A comprehensive Git management tool that integrates SSH authentication, GitHub MCP (Model Context Protocol), and a skill-based workflow system to streamline your Git operations.

## Features

### 🔐 SSH Authentication
- Automatic SSH certificate authentication to GitHub
- Secret key file configuration via `.env`
- Secure credential management

### 🔌 GitHub MCP Integration
- Built-in GitHub MCP support
- Seamless integration with GitHub's Model Context Protocol
- Enhanced Git operations through MCP tools

### 🎯 Skill-Based Workflow
- Intelligent request matching with pre-defined skills
- Dynamic skill loading and execution
- Custom skill creation with user collaboration
- Iterative skill refinement process

## Getting Started

### Prerequisites

- Git installed on your system
- GitHub account with SSH access
- SSH key pair generated

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd <repository-name>
```

2. Create your `.env` file:
```bash
cp .env.example .env
```

3. Configure your `.env` file:
```env
SSH_KEY_PATH=/path/to/your/ssh/private/key
GITHUB_USERNAME=your-github-username
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_github_personal_access_token
# Add other necessary environment variables
```

4. Register the GitHub MCP server for Codex:
```bash
codex mcp add github -- /bin/zsh -lc 'set -a; [ -f /path/to/github-manager/.env ] && source /path/to/github-manager/.env; exec npx -y @modelcontextprotocol/server-github'
```

5. Verify MCP registration:
```bash
codex mcp list
codex mcp get github
```

## Usage

### SSH Authentication

The system automatically authenticates your SSH certificate to GitHub using the secret key file specified in your `.env` configuration:

```bash
# The system handles authentication automatically
# Ensure your SSH_KEY_PATH is correctly set in .env
```

### Working with Skills

#### Using Existing Skills

When you make a request, the system:
1. Checks for matching skills in the skill library
2. Loads the appropriate skill instruction
3. Processes required GitHub MCP tools
4. Executes the workflow

Example:
```bash
# Your request is automatically matched with existing skills
$ "Create a new feature branch from main"
# System finds matching skill and executes
```

#### Creating New Skills

If no existing skill matches your request:

1. The system prompts you to create a new skill
2. You collaborate with the system to define skill instructions
3. **During refinement, the system determines which GitHub MCP tools are needed**
4. MCP tools are configured in the skill definition for fast runtime execution
5. Iterative refinement loop ensures completeness
6. After creation, reload to enable the new skill

Example workflow:
```
User: "I need to sync my fork with upstream and create a PR"
System: "No matching skill found. Would you like to create a new skill?"
User: "Yes"
System: "Let's define this skill. What should it do first?"
User: "Fetch upstream, merge into my fork, push, then create PR"
System: "I'll configure these GitHub MCP tools for this skill:
         - git_fetch (for upstream sync)
         - git_merge (for merging changes)
         - git_push (for pushing to fork)
         - create_pull_request (for PR creation)
         Does this cover your workflow?"
User: "Yes, that's perfect"
System: "Skill created with pre-configured MCP tools! Please reload to enable it."
```

**Benefits of determining MCP tools during refinement:**
- ⚡ Faster runtime execution (no tool selection overhead)
- 🎯 More accurate tool usage
- 📝 Clear skill documentation
- 🔧 Easier skill maintenance

### GitHub MCP Tools

The system leverages GitHub MCP tools that are **pre-configured during skill creation** for optimal performance:

#### Available MCP Tools

**Repository Operations:**
- `create_repository` - Create new repositories
- `fork_repository` - Fork existing repositories
- `clone_repository` - Clone repositories locally

**Branch Management:**
- `create_branch` - Create new branches
- `delete_branch` - Remove branches
- `list_branches` - View all branches
- `checkout_branch` - Switch between branches

**Commit Operations:**
- `git_commit` - Create commits
- `git_push` - Push changes to remote
- `git_pull` - Pull changes from remote
- `git_fetch` - Fetch remote changes
- `git_merge` - Merge branches

**Pull Request Workflow:**
- `create_pull_request` - Create new PRs
- `update_pull_request` - Modify existing PRs
- `merge_pull_request` - Merge PRs
- `list_pull_requests` - View PRs
- `review_pull_request` - Add PR reviews

**Issue Management:**
- `create_issue` - Create new issues
- `update_issue` - Modify issues
- `close_issue` - Close issues
- `list_issues` - View issues

**Code Review:**
- `add_comment` - Comment on code
- `request_review` - Request reviews
- `approve_changes` - Approve PRs

#### How Skills Use MCP Tools

Each skill's `config.json` specifies exactly which tools are needed:

```json
{
  "skill_name": "hotfix-workflow",
  "mcp_tools": [
    {"tool": "create_branch", "params": {"base": "main", "name": "hotfix/*"}},
    {"tool": "git_commit", "params": {"message": "Fix: {description}"}},
    {"tool": "git_push", "params": {"remote": "origin"}},
    {"tool": "create_pull_request", "params": {"base": "main", "draft": false}}
  ]
}
```

At runtime, the system:
1. Loads the skill configuration
2. Reads the pre-configured MCP tools list
3. Executes tools in sequence with specified parameters
4. No tool selection logic needed - everything is predefined

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SSH_KEY_PATH` | Path to your SSH private key | Yes |
| `GITHUB_USERNAME` | Your GitHub username | Yes |
| `MCP_ENDPOINT` | GitHub MCP endpoint (if custom) | No |

### Skill Configuration

Skills are stored in the `skills/` directory. Each skill contains:
- Skill instruction file
- Required MCP tools mapping
- Execution parameters

## Skill Management

### Skill Creation and Refinement Process

When creating a new skill, the system guides you through a structured refinement process:

#### Step 1: Define the Workflow
```
System: "Describe what you want this skill to accomplish"
User: "Sync my fork with upstream and create a PR"
```

#### Step 2: Break Down Actions
```
System: "Let's break this into steps. What happens first?"
User: "Fetch from upstream"
System: "Then what?"
User: "Merge into my main branch, push to origin, create PR"
```

#### Step 3: Determine MCP Tools (Critical Step)
```
System: "Based on your workflow, I'll configure these GitHub MCP tools:
         
         1. git_fetch - for syncing with upstream
         2. git_merge - for integrating changes
         3. git_push - for updating your fork
         4. create_pull_request - for initiating the PR
         
         Do these tools match your needs?"
User: "Yes"
```

#### Step 4: Configure Tool Parameters
```
System: "Let's configure each tool:
         
         git_fetch:
         - Which remote? (default: upstream)
         - Which branch? (default: main)
         
         Should I use these defaults?"
User: "Yes, that works"
```

#### Step 5: Save and Enable
```
System: "Skill created with pre-configured MCP tools!
         
         Saved to: skills/custom-skills/sync-fork-and-pr/
         - instruction.md (workflow description)
         - config.json (MCP tools + parameters)
         
         Please run 'reload-skills' to enable this skill."
```

### Why Pre-configure MCP Tools?

| Aspect | Without Pre-configuration | With Pre-configuration |
|--------|---------------------------|------------------------|
| **Runtime Performance** | Analyze request → Select tools → Execute | Load config → Execute |
| **Accuracy** | May select wrong tools | Tools verified during creation |
| **Consistency** | Different tools each time | Same tools every execution |
| **Debugging** | Hard to trace tool selection | Clear tool chain in config |
| **Time to Execute** | 2-5 seconds overhead | < 100ms overhead |

### Skill Structure

```
skills/
├── branch-management/
│   ├── instruction.md
│   └── config.json          # Contains pre-configured MCP tools
├── pr-workflow/
│   ├── instruction.md
│   └── config.json
└── custom-skills/
    └── sync-fork-and-pr/
        ├── instruction.md
        └── config.json      # MCP tools determined during creation
```

#### Example Skill Configuration

**config.json**
```json
{
  "skill_name": "sync-fork-and-pr",
  "description": "Sync fork with upstream and create pull request",
  "mcp_tools": [
    {
      "tool": "git_fetch",
      "params": {
        "remote": "upstream",
        "branch": "main"
      }
    },
    {
      "tool": "git_merge",
      "params": {
        "source": "upstream/main",
        "target": "main"
      }
    },
    {
      "tool": "git_push",
      "params": {
        "remote": "origin",
        "branch": "main"
      }
    },
    {
      "tool": "create_pull_request",
      "params": {
        "base": "main",
        "head": "feature-branch"
      }
    }
  ],
  "version": "1.0.0",
  "created_at": "2024-02-23"
}
```

**instruction.md**
```markdown
# Sync Fork and Create PR

## Objective
Synchronize a forked repository with its upstream source and create a pull request.

## Steps
1. Fetch latest changes from upstream repository
2. Merge upstream changes into local main branch
3. Push updated main to origin (your fork)
4. Create pull request from feature branch to upstream

## MCP Tools Used
- git_fetch: Retrieves upstream changes
- git_merge: Integrates upstream into fork
- git_push: Updates remote fork
- create_pull_request: Initiates PR workflow

## Expected Outcome
Fork is synchronized and PR is created successfully.
```

### Reloading Skills

After creating or modifying skills:
```bash
# Reload the system to enable new skills
$ reload-skills
```

## Architecture

```
┌─────────────────┐
│  User Request   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Skill Matcher  │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────┐   ┌──────────────────┐
│Found│   │    Not Found     │
└──┬──┘   └────────┬─────────┘
   │               │
   │               ▼
   │      ┌────────────────────┐
   │      │  Skill Creator     │
   │      │  (Interactive)     │
   │      └────────┬───────────┘
   │               │
   │               ▼
   │      ┌────────────────────┐
   │      │  Refine & Define   │
   │      │  Required MCP Tools│ ◄── Tools determined HERE
   │      └────────┬───────────┘
   │               │
   │               ▼
   │      ┌────────────────────┐
   │      │  Save Skill with   │
   │      │  Pre-configured    │
   │      │  MCP Tools         │
   │      └────────┬───────────┘
   │               │
   │               ▼
   │      ┌────────────────────┐
   │      │  Reload Required   │
   │      └────────────────────┘
   │
   └─────────┬────────────────────────┐
             │                        │
             ▼                        ▼
    ┌────────────────┐      ┌────────────────┐
    │  Load Skill    │      │  Load MCP Tools│
    │  Instructions  │      │  from Config   │ ◄── Fast lookup
    └────────┬───────┘      └────────┬───────┘
             │                        │
             └───────────┬────────────┘
                         │
                         ▼
                ┌────────────────┐
                │ Execute GitHub │
                │ MCP Tools      │
                │ (Pre-defined)  │
                └────────┬───────┘
                         │
                         ▼
                ┌────────────────┐
                │    Complete    │
                └────────────────┘
```

### Key Architecture Benefits

1. **Skill Creation Phase** (One-time)
   - Interactive refinement with user
   - MCP tools determined and configured
   - Saved in skill config for reuse

2. **Skill Execution Phase** (Runtime)
   - Fast skill matching
   - Instant MCP tool loading from config
   - No runtime tool selection overhead
   - Efficient execution

## Security

- SSH keys are never committed to the repository
- `.env` file is gitignored by default
- Credentials are loaded securely from environment variables
- MCP authentication follows GitHub's security best practices

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Troubleshooting

### SSH Authentication Issues

```bash
# Verify your SSH key is correctly configured
ssh -T git@github.com

# Check .env configuration
cat .env | grep SSH_KEY_PATH
```

### Skill Not Loading

1. Verify skill syntax in instruction file
2. Check config.json for errors
3. Reload skills after modifications
4. Check system logs for errors

## License

[Your License Here]

## Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation
- Review skill examples in `skills/` directory

---

**Note**: This system requires proper SSH configuration and GitHub MCP access. Ensure all prerequisites are met before use.
