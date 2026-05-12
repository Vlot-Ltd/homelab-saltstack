# Homelab SaltStack

Homelab SaltStack code to experiment and manage systems.

**Author:** Timo Vlot  
**Type:** Homelab Project  
**Framework:** PEP (Project Enhancement Packages)

## Quick Start

```bash
# Create your first PEP (planning document)
./tools/pep-tools.sh new-pep "Project Foundation"

# List all PEPs
./tools/pep-tools.sh list

# Get help with commands
./tools/pep-tools.sh help
```

## PEP Framework Overview

This project uses **Project Enhancement Packages (PEPs)** for structured development:

- **PEP** = Planning document created BEFORE implementation
- **BLOG** = Build log documenting what was actually implemented  
- **Git Integration** = Automatic linking between code and documentation

### Core Workflow

1. **Plan**: Create a PEP describing what you want to build
2. **Implement**: Write code with proper git commit references
3. **Document**: Create a BLOG recording what was actually built

```bash
# 1. Plan your work
./tools/pep-tools.sh new-pep "Nutanix Integration"

# 2. Implement with git integration
git checkout -b feature/pep-002-nutanix-integration
git commit -m "pep-002: Add Nutanix API client"
git commit -m "pep-002: Implement cluster monitoring"

# 3. Document implementation
./tools/pep-tools.sh new-blog 1 2
```

## Project-Specific Guidelines



### Homelab Project Guidelines

**Focus Areas:**

- Virtual machine and container management
- Network configuration and security
- Service deployment and maintenance
- Hardware upgrades and power management

**PEP Requirements:**

- Document power consumption and cooling impact
- Include network topology changes
- Specify backup and recovery procedures
- Consider family/household impact

**Common Tools Integration:**

```bash
# Proxmox VM management
qm create/start/stop pep-XXX-vm

# Docker service deployment
docker-compose -f docker/pep-XXX-compose.yml up -d

# TrueNAS storage configuration
# Document dataset and share changes

# Network configuration
# Document VLAN and firewall changes
```

**Service Management:**

- Document service dependencies and startup order
- Include troubleshooting procedures for family members
- Plan for maintenance windows and service disruption



## Configuration

Current project settings (edit `.peprc` to modify):

- **Author:** Timo Vlot
- **Editor:** vi
- **Project Type:** homelab

- **Git Hooks:** Enabled (validates PEP references)



- **Zabbix:** zabbix.taile3eee.ts.net


- **Grafana:** http://100.107.102.4:3000/l


## Available Commands

```bash
# PEP Management
./tools/pep-tools.sh new-pep [number] [title]    # Create new PEP
./tools/pep-tools.sh list                        # List all PEPs
./tools/pep-tools.sh status                      # Show status summary

# BLOG Management  
./tools/pep-tools.sh new-blog [blog-num] [pep-num]  # Create implementation blog

# Help
./tools/pep-tools.sh help                        # Show all commands
```

## Git Integration


**Git hooks are enabled** - commit messages are automatically validated.

**Branch Naming Convention:**

- `feature/pep-XXX-description` - New features
- `fix/pep-XXX-issue` - Bug fixes  
- `docs/pep-XXX-update` - Documentation updates

**Commit Message Format:**

- `pep-XXX: description` - Changes related to specific PEP
- `docs: update README` - Documentation-only changes
- `chore: maintenance tasks` - Non-PEP maintenance

**Validation Rules:**

- Commits referencing PEPs must use correct format
- Referenced PEPs must exist
- Warnings for commits to rejected/superseded PEPs



## Claude AI Integration

Each PEP includes a **Claude Prompt Context** section designed for AI assistance:

1. **Copy context** from your PEP's "Claude Prompt Context" section
2. **Paste into Claude** with your specific request
3. **Get tailored help** based on your project's requirements and constraints

Example workflow:

```bash
# 1. Create PEP with Claude context
./tools/pep-tools.sh new-pep "Database Migration"

# 2. Copy the "Claude Prompt Context" section from PEP-003

# 3. Use with Claude:
# "Using the context below, help me design the database migration strategy..."
```

## Directory Structure

```bash
homelab-saltstack/
├── .peprc                      # Project configuration
├── README.md                   # This file
├── docs/
│   ├── peps/                   # Project Enhancement Packages
│   │   └── pep-001-foundation.md (create this first)
│   ├── blogs/                  # Build Logs (implementation records)
│   └── templates/              # PEP and BLOG templates
│       ├── pep-template.md
│       └── blog-template.md
├── tools/
│   ├── pep-tools.sh           # Management CLI tool
│   └── git-hooks/
│       └── commit-msg         # Git integration hook
└── .gitignore
```

## Best Practices

### PEP Creation

1. **Start with PEP-001** - Document current project state and foundation
2. **Be specific** - Clear requirements and success criteria
3. **Include monitoring** - How will you know it's working?
4. **Plan phases** - Break large changes into manageable pieces
5. **Prepare AI context** - Include information for Claude assistance

### Implementation

1. **Create feature branches** - Use `feature/pep-XXX-description`
2. **Commit frequently** - Reference PEP numbers in all commits
3. **Document deviations** - When implementation differs from plan
4. **Test thoroughly** - Include validation in your implementation
5. **Monitor results** - Verify success criteria are met

### Documentation  

1. **Create BLOGs** - Document what was actually built
2. **Record lessons** - What worked, what didn't, what changed
3. **Update PEPs** - Revise plans when understanding evolves
4. **Maintain traceability** - Link code changes to planning documents
5. **Share knowledge** - Help others understand your decisions

## Getting Help

- **Tool usage:** `./tools/pep-tools.sh help`
- **Framework concepts:** See cookiecutter template documentation
- **Project issues:** Contact Timo Vlot (timo@vlot.org.uk)
- **Git integration:** Check `.git/hooks/commit-msg` for validation rules

## Example: Your First PEP

```bash
# Create foundation PEP
./tools/pep-tools.sh new-pep "Project Foundation"

# This creates docs/peps/pep-001-project-foundation.md
# Edit it to document:
# - Current state of the project
# - Technology stack and architecture
# - Development standards and practices  
# - Future enhancement roadmap
```

This PEP-001 becomes your project's "constitution" - a reference document that evolves as your project grows.# Homelab SaltStack

Homelab SaltStack code to experiment and manage systems.

## PEP Framework Integration

This project uses the **Project Enhancement Package (PEP)** framework for structured development and documentation.

### Quick Guide

```bash
# List current PEPs
./tools/pep-tools.sh list

# Create a new PEP for your enhancement
./tools/pep-tools.sh new-pep "Your Feature Name"

# Work on the feature
git checkout -b feature/pep-XXX-your-feature
# ... make changes ...
git commit -m "pep-XXX: Implement your feature"

# Document implementation
./tools/pep-tools.sh new-blog XXX YYY
```

### Project Information

- **Author:** Timo Vlot
- **Type:** Homelab Project
- **Framework Version:** 1.0

### Project-Specific Guidelines



#### Homelab Project Guidelines

- **PEPs should address:** Service deployments, network changes, hardware upgrades
- **Common tools:** Docker, Proxmox, TrueNAS, home automation
- **Documentation:** Include power requirements, network topology changes
- **Backup:** Document backup implications of changes

#### Docker Integration

```bash
# Reference docker-compose files in BLOGs
docker-compose -f docker/pep-XXX-compose.yml up -d
```

#### Service Management

```bash
# Document service dependencies and startup order
systemctl enable pep-XXX-service
```



### Configuration

Project-specific settings in `.peprc`:


- **Zabbix Host:** zabbix.taile3eee.ts.net


- **Grafana URL:** http://100.107.102.4:3000/l

- **Default Editor:** vi


### Current PEPs

| PEP | Title | Status | Author |
|-----|-------|--------|--------|
| 001 | Project Foundation | Draft | Timo Vlot |

*Use `./tools/pep-tools.sh list` for current status*

### Getting Help

- **PEP Framework:** See main framework documentation
- **Project Issues:** Contact Timo Vlot (timo@vlot.org.uk)
- **Tool Usage:** `./tools/pep-tools.sh help`

### Contributing

1. Create a PEP describing your proposed change
2. Get PEP reviewed and approved
3. Implement following git workflow conventions
4. Document implementation in a BLOG
5. Update this README if needed
