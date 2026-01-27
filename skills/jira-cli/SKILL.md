---
name: jira-cli
summary: Feature-rich interactive CLI for Atlassian Jira. Provides issue management, epic/sprint navigation, transitions, and more from the command line.
triggers:
  - jira-cli
  - jira command line
  - jira issue list
  - jira issue create
  - jira sprint
  - jira epic
  - atlassian jira cli
  - ticket management cli
  - jira from terminal
  - move jira ticket
  - transition jira issue
---

# Jira CLI

## Overview

JiraCLI is an interactive command line tool for Atlassian Jira that helps avoid the Jira UI for common tasks. It provides an interactive TUI for browsing issues, creating tickets, managing sprints/epics, transitioning issues, and more.

**Repository**: https://github.com/ankitpokhrel/jira-cli
**Doc Version**: v1.7.0 (Aug 31, 2025)

### Supported Platforms

| Platform | Support |
|----------|---------|
| **OS** | Linux, macOS, FreeBSD, NetBSD, Windows |
| **Jira** | Jira Cloud, Jira Server (on-premise) |

## When Not to Use This Skill

- **Bulk data exports**: Use Jira's native CSV/JSON export or REST API directly for large data migrations
- **Jira administration**: User management, permissions, and scheme configuration require the Jira admin UI
- **Complex JQL reporting**: For dashboards and advanced reporting, use Jira's built-in gadgets or third-party BI tools
- **Webhook configuration**: Must be done through Jira settings
- **Custom field type creation**: Requires admin UI access

## Installation

### Homebrew (macOS/Linux)

```bash
brew install ankitpokhrel/jira-cli/jira-cli
```

### Go Install

```bash
go install github.com/ankitpokhrel/jira-cli/cmd/jira@latest
```

### Docker

```bash
docker run -it --rm ghcr.io/ankitpokhrel/jira-cli:latest
```

### Pre-built Binaries

Download from [releases page](https://github.com/ankitpokhrel/jira-cli/releases) for your platform.

## Authentication

### Cloud Server

1. Get a [Jira API token](https://id.atlassian.com/manage-profile/security/api-tokens)
2. Export it:
   ```bash
   export JIRA_API_TOKEN="your-api-token"
   ```
3. Run initialization:
   ```bash
   jira init
   ```
   Select "Cloud" and provide your Jira URL and email.

### On-Premise (Server/Data Center)

1. For basic auth, export your password:
   ```bash
   export JIRA_API_TOKEN="your-password"
   ```
2. For PAT (Personal Access Token):
   ```bash
   export JIRA_API_TOKEN="your-pat-token"
   export JIRA_AUTH_TYPE="bearer"
   ```
3. Run initialization:
   ```bash
   jira init
   ```
   Select "Local" and choose auth type (basic, bearer, or mtls).

### Authentication Types

| Type | Use Case | Setup |
|------|----------|-------|
| `basic` | Username/password login | Default, no extra config |
| `bearer` | Personal Access Token | Set `JIRA_AUTH_TYPE=bearer` |
| `mtls` | Client certificates | Select during `jira init`, provide certs |

## Configuration

Config file location: `~/.config/.jira/.config.yml`

### Environment Variables

```bash
JIRA_API_TOKEN          # Required: API token or password
JIRA_AUTH_TYPE          # Optional: "bearer" for PAT auth
JIRA_CONFIG_FILE        # Optional: Path to config file
```

### Multiple Projects

```bash
# Use environment variable
JIRA_CONFIG_FILE=./project_jira.yaml jira issue list

# Or use --config flag
jira issue list -c ./project_jira.yaml
```

### Shell Completion

```bash
# Bash
jira completion bash > /etc/bash_completion.d/jira

# Zsh
jira completion zsh > "${fpath[1]}/_jira"

# Check help for more
jira completion --help
```

## Core Commands

### Issue Management

#### List Issues

```bash
# List recent issues
jira issue list

# List with filters
jira issue list -s"To Do"                    # By status
jira issue list -yHigh                        # By priority
jira issue list -a$(jira me)                  # Assigned to me
jira issue list -r"User Name"                 # Reported by
jira issue list -lbackend                     # By label
jira issue list -tBug                         # By type
jira issue list --created month               # Created this month
jira issue list --created -7d                 # Created in last 7 days
jira issue list -w                            # Issues I'm watching

# Output formats
jira issue list --plain                       # Plain text (no TUI)
jira issue list --raw                         # Raw JSON
jira issue list --csv                         # CSV format

# Raw JQL
jira issue list -q "summary ~ cli"

# Combine filters
jira issue list -yHigh -s"To Do" --created month -lbackend -a$(jira me)
```

#### Create Issue

```bash
# Interactive
jira issue create

# With parameters
jira issue create -tBug -s"New Bug" -yHigh -lbug -b"Description" --no-input

# Attach to epic
jira issue create -tStory -s"Story name" -PEPIC-42

# From template
jira issue create --template /path/to/template.md

# From stdin
echo "Description" | jira issue create -s"Summary" -tTask
```

#### Edit Issue

```bash
jira issue edit ISSUE-1
jira issue edit ISSUE-1 -s"New summary" -yHigh --no-input

# Add/remove labels (minus removes)
jira issue edit ISSUE-1 --label -old --label new

# Add/remove components
jira issue edit ISSUE-1 --component -FE --component BE
```

#### View Issue

```bash
jira issue view ISSUE-1
jira issue view ISSUE-1 --comments 5    # Show 5 recent comments
```

#### Assign Issue

```bash
jira issue assign                       # Interactive
jira issue assign ISSUE-1 "John Doe"    # Assign to user
jira issue assign ISSUE-1 $(jira me)    # Assign to self
jira issue assign ISSUE-1 default       # Default assignee
jira issue assign ISSUE-1 x             # Unassign
```

#### Move/Transition Issue

```bash
jira issue move                         # Interactive
jira issue move ISSUE-1 "In Progress"
jira issue move ISSUE-1 Done -RFixed -a$(jira me)  # With resolution and assignee
jira issue move ISSUE-1 "In Progress" --comment "Started working"
```

#### Link Issues

```bash
jira issue link                         # Interactive
jira issue link ISSUE-1 ISSUE-2 Blocks

# Remote web link
jira issue link remote ISSUE-1 https://example.com "Link text"
```

#### Unlink Issues

```bash
jira issue unlink ISSUE-1 ISSUE-2
```

#### Clone Issue

```bash
jira issue clone ISSUE-1
jira issue clone ISSUE-1 -s"Modified summary" -yHigh -a$(jira me)
jira issue clone ISSUE-1 -H"find:replace"   # Replace text in summary/description
```

#### Delete Issue

```bash
jira issue delete ISSUE-1
jira issue delete ISSUE-1 --cascade     # Delete with subtasks
```

#### Comments

```bash
jira issue comment add                  # Interactive
jira issue comment add ISSUE-1 "Comment body"
jira issue comment add ISSUE-1 "Internal note" --internal
jira issue comment add ISSUE-1 --template /path/to/template.md
```

#### Worklog

```bash
jira issue worklog add                  # Interactive
jira issue worklog add ISSUE-1 "2d 3h 30m" --no-input
jira issue worklog add ISSUE-1 "10m" --comment "Time tracking" --no-input
```

### Epic Management

```bash
# List epics
jira epic list
jira epic list --table                  # Table view

# List issues in epic
jira epic list EPIC-1
jira epic list EPIC-1 -ax -yHigh        # Unassigned, high priority

# Create epic
jira epic create -n"Epic Name" -s"Summary" -yHigh -b"Description"

# Add issues to epic (up to 50)
jira epic add EPIC-1 ISSUE-1 ISSUE-2

# Remove issues from epic
jira epic remove ISSUE-1 ISSUE-2
```

### Sprint Management

```bash
# List sprints
jira sprint list
jira sprint list --table

# List sprint issues
jira sprint list --current              # Current active sprint
jira sprint list --prev                 # Previous sprint
jira sprint list --next                 # Next planned sprint
jira sprint list --state future,active  # By state
jira sprint list SPRINT_ID              # Specific sprint

# Filter sprint issues
jira sprint list --current -a$(jira me) -yHigh

# Add issues to sprint (up to 50)
jira sprint add SPRINT_ID ISSUE-1 ISSUE-2
```

### Releases

```bash
jira release list
jira release list --project KEY
```

### Navigation Commands

```bash
jira open                               # Open project in browser
jira open ISSUE-1                       # Open issue in browser
jira project list                       # List accessible projects
jira board list                         # List boards in project
jira me                                 # Print current user
```

## Interactive UI Navigation

When using the interactive TUI:

| Key | Action |
|-----|--------|
| `↑/↓` or `j/k` | Navigate list |
| `←/→` or `h/l` | Horizontal scroll |
| `g` / `G` | Jump to top/bottom |
| `Ctrl+f` / `Ctrl+b` | Page down/up |
| `Enter` | Open in browser |
| `v` | View issue details |
| `m` | Transition issue |
| `c` | Copy issue URL |
| `Ctrl+k` | Copy issue key |
| `Ctrl+r` / `F5` | Refresh |
| `w` / `Tab` | Toggle sidebar focus |
| `?` | Help |
| `q` / `ESC` / `Ctrl+c` | Quit |

## Common Workflows

### Quick Issue Triage

```bash
# What tickets did I create today?
jira issue list -r$(jira me) --created -1d

# What's assigned to me and open?
jira issue list -a$(jira me) -s~Done

# High priority bugs in current sprint
jira sprint list --current -tBug -yHigh
```

### Daily Standup Prep

```bash
# My in-progress issues
jira issue list -a$(jira me) -s"In Progress"

# My recent activity
jira issue list --history
```

### Sprint Review

```bash
# Completed issues in current sprint
jira sprint list --current -sDone

# Issues per assignee in sprint
jira sprint list SPRINT_ID --plain --columns assignee --no-headers | sort | uniq -c
```

### Create Bug with Template

```bash
cat <<'EOF' | jira issue create -tBug -s"Login fails on mobile" --template -
## Steps to Reproduce
1. Open app on mobile
2. Enter credentials
3. Tap login

## Expected
User should be logged in

## Actual
App crashes with error XYZ

## Environment
- iOS 17.0
- App version 2.3.1
EOF
```

### Bulk Operations (Scripts)

```bash
# Count tickets created per day this month
jira issue list --created month --plain --columns created --no-headers | \
  awk '{print $2}' | awk -F'-' '{print $3}' | sort -n | uniq -c
```

## Troubleshooting

### "No project found"

Ensure you've run `jira init` and configured a default project:

```bash
jira init
```

### Authentication Errors

```bash
# Verify token is set
echo $JIRA_API_TOKEN

# For PAT auth, ensure auth type is set
echo $JIRA_AUTH_TYPE  # Should be "bearer"

# Re-initialize
jira init
```

### Non-English Jira Installation

For on-premise Jira with non-English language, manually configure epic fields in `~/.config/.jira/.config.yml`:

```yaml
epic:
  name: "Epic Name Field ID"
  link: "Epic Link Field ID"
```

### Rate Limiting

For heavy usage, add delays between commands or use the `--plain` flag to reduce API calls.

### Proxy Issues

Set standard proxy environment variables:

```bash
export HTTP_PROXY=http://proxy:8080
export HTTPS_PROXY=http://proxy:8080
```

## Best Practices

1. **Use `--plain` for scripts**: Disables TUI for reliable parsing
2. **Combine with shell aliases**: Create shortcuts for common queries
3. **Use templates**: Store issue templates for consistent formatting
4. **Leverage JQL**: Use `-q` flag for complex queries beyond built-in filters
5. **Shell completion**: Enable for faster command entry

### Useful Aliases

```bash
# Add to ~/.bashrc or ~/.zshrc
alias jme='jira issue list -a$(jira me)'
alias jtodo='jira issue list -a$(jira me) -s"To Do"'
alias jinprog='jira issue list -a$(jira me) -s"In Progress"'
alias jsprint='jira sprint list --current -a$(jira me)'
alias jview='jira issue view'
alias jmove='jira issue move'
```

## Resources

- [JiraCLI GitHub Repository](https://github.com/ankitpokhrel/jira-cli)
- [JiraCLI FAQs](https://github.com/ankitpokhrel/jira-cli/discussions/categories/faqs)
- [JiraCLI Wiki](https://github.com/ankitpokhrel/jira-cli/wiki)
- [Jira REST API Documentation](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
- [JQL Reference](https://support.atlassian.com/jira-software-cloud/docs/use-advanced-search-with-jira-query-language-jql/)
