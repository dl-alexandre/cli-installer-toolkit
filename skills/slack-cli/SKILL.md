---
name: slack-cli
summary: Command-line interface for creating and managing Slack apps, used with Deno Slack SDK or Bolt frameworks for JavaScript and Python
triggers:
  - slack cli
  - slack-cli
  - slack command line
  - create slack app
  - manage slack app
  - slack app development
  - slack app lifecycle
  - deploy slack app
  - slack app authorization
  - slack bolt framework
  - deno slack sdk
---
# Slack CLI

## Overview

The Slack CLI is a command-line tool for creating and managing Slack apps throughout their entire lifecycle. It's the recommended way to develop Slack apps, working in combination with the Deno Slack SDK or Bolt frameworks for JavaScript, Python, and Java.

The CLI handles app creation, installation, deployment, and administration tasks that would otherwise require using the Slack web interface or manual API calls.

**Documentation**: https://docs.slack.dev/tools/slack-cli  
**Repository**: https://github.com/slackapi/slack-cli (open source)

## When Not to Use This Skill

- **Sending messages or notifications**: Use Slack webhooks or the Web API directly, not the CLI
- **One-off API calls**: Use `curl` with Slack Web API tokens for simple requests
- **Workflow Builder automation**: The CLI is for app development, not no-code workflow creation
- **Production app management**: CLI is primarily for development; use Slack's app management UI for production settings
- **Enterprise Grid administration**: Requires additional setup and may have limitations

## Core Commands / Usage

### Authentication

Authorize the CLI with your Slack workspace:

```bash
slack login
```

This opens a browser for OAuth authentication. The CLI stores credentials securely.

For multiple workspaces:
```bash
slack login --team workspace-name
slack auth list                    # List all authorized accounts
```

### App Creation

Create a new Slack app:

```bash
slack create my-app                # Global alias for project create
slack project create my-app        # Full command
slack create my-app -t slack-samples/deno-hello-world  # With template
```

### Running Apps Locally

Start your app in development mode:

```bash
slack run                          # Global alias for platform run
slack platform run                 # Full command
slack run -v                       # Verbose mode
```

### Deployment

Deploy your app:

```bash
slack deploy                       # Global alias for platform deploy
slack platform deploy              # Full command
slack deploy --team workspace-name
```

### App Management

```bash
slack app list                     # List teams with the app installed
slack app install                  # Install the app to a team
slack app uninstall                # Uninstall the app from a team
slack app delete                   # Delete the app
slack app link                     # Add an existing app to the project
slack app unlink                   # Remove a linked app from the project
slack app settings                 # Open app settings for configurations
```

### Authentication Commands

```bash
slack auth list                    # List all authorized accounts
slack auth login                   # Log in to a Slack account
slack auth logout                  # Log out of a team
slack auth revoke                  # Revoke an authentication token
slack auth token                   # Collect a service token
```

## Common Workflows

### Creating a New Slack App

1. Authenticate: `slack login`
2. Create app: `slack create my-app` or use a template: `slack create my-app -t slack-samples/deno-hello-world`
3. Navigate to app directory: `cd my-app`
4. Run locally: `slack run`
5. Deploy: `slack deploy`

### Working with Bolt Framework

The CLI integrates seamlessly with Bolt frameworks. Use templates from `slack-samples`:

**JavaScript:**
```bash
slack create my-app -t slack-samples/bolt-js-starter-template
cd my-app
slack run
```

**Python:**
```bash
slack create my-app -t slack-samples/bolt-python-starter-template
cd my-app
slack run
```

### Using with Deno Slack SDK

```bash
slack create my-app -t slack-samples/deno-hello-world
cd my-app
slack run
```

### CI/CD Integration

The CLI can be used in CI/CD pipelines:

```bash
slack login --token $SLACK_TOKEN
slack deploy
```

### Additional Commands

```bash
slack doctor                      # Check system and app information
slack version                     # Print CLI version
slack upgrade                     # Check for available updates
slack project init                # Initialize existing project
slack project samples             # List available sample apps
slack manifest info               # Print app manifest
slack manifest validate           # Validate app manifest
slack platform activity           # Display app activity logs
```

## Configuration

### Environment Variables

- `SLACK_CLI_TOKEN`: Authentication token (set automatically after `slack login`)
- `SLACK_CLI_TEAM`: Default workspace/team ID
- `SLACK_CLI_DEBUG`: Enable debug output (`true`/`false`)

### Configuration Files

The CLI stores configuration in:
- `~/.slack/` (macOS/Linux)
- `%APPDATA%\slack\` (Windows)

Configuration includes:
- Authentication tokens
- Workspace settings
- App metadata

### Workspace Selection

Switch between workspaces:

```bash
slack login --team workspace-name
slack auth list                    # View all authorized accounts
```

## Troubleshooting

### Authentication Issues

**Problem**: `slack login` fails or times out

**Solutions**:
- Ensure you have workspace admin permissions
- Try `slack logout` then `slack login` again
- Check network connectivity
- Verify browser popup blockers aren't blocking OAuth

### App Deployment Failures

**Problem**: `slack deploy` fails

**Solutions**:
- Verify app manifest is valid
- Check that required scopes are configured
- Ensure app is properly authenticated
- Review error messages for specific issues

### Local Development Issues

**Problem**: `slack run` doesn't start

**Solutions**:
- Verify Node.js version (v14+)
- Check that dependencies are installed (`npm install`)
- Ensure port isn't already in use
- Review app logs for errors

### Common Error Messages

- **"Not authenticated"**: Run `slack login`
- **"App not found"**: Verify app ID or create new app with `slack project create`
- **"Permission denied"**: Check workspace permissions
- **"unknown command"**: Use `slack --help` to see available commands
- **"Port already in use"**: The CLI manages ports automatically; check for other running instances

## Integration with This Project

This project uses Slack webhooks for notifications (see `CLAUDE.md` for webhook configuration). The Slack CLI is separate from webhook usage:

- **Webhooks**: For sending notifications to Slack channels/users
- **Slack CLI**: For developing and managing Slack apps

If you need to create a Slack app that integrates with this project's monitoring or repository management features, use the Slack CLI to create and deploy the app.

## Comparison with Similar Tools

- **Slack Web API**: Direct HTTP calls to Slack APIs (use for simple integrations)
- **Bolt Framework**: High-level framework for building apps (works with CLI)
- **Slack App Settings UI**: Web interface for app configuration (CLI complements this)

## Best Practices

1. **Use templates**: Start with `--template` flag for proper project structure
2. **Local development first**: Always test with `slack run` before deploying
3. **Version control**: Commit your app code, but not tokens or secrets
4. **Environment variables**: Use `.env` files for configuration (gitignored)
5. **Workspace isolation**: Use separate workspaces for development and production

## Resources

- **Official Documentation**: https://docs.slack.dev/tools/slack-cli
- **Commands Reference**: https://api.slack.com/reference/cli
- **Bolt Framework**: https://slack.dev/bolt-js/
- **Deno Slack SDK**: https://deno.land/x/slack_sdk
- **Issue Tracker**: https://github.com/slackapi/slack-cli/issues
- **Support**: support@slack.com

## Notes

- The CLI is the recommended way to manage Slack apps (replaces manual web UI workflows)
- Works with Bolt frameworks (JavaScript, Python, Java) and Deno Slack SDK
- Supports local development with hot-reload capabilities
- Handles OAuth authentication automatically
- Open source and actively maintained by Slack

**Documentation Version**: Based on docs.slack.dev/tools/slack-cli (2024)

## Installation Reference

### Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- A Slack workspace where you have permission to create apps

### Installation Steps

**macOS / Linux:**
```bash
npm install -g @slack/cli
```

Or use the installation script:
```bash
curl -fsSL https://slack.dev/install | sh
```

**Windows:**
```bash
npm install -g @slack/cli
```

**Verify installation:**
```bash
slack --version
```

**Updating:**
```bash
npm update -g @slack/cli
```
