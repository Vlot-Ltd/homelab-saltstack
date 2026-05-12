#!/bin/bash
# PEP Management Tools
# Version: 1.0
# Description: Command-line tools for managing Project Enhancement Packages

set -e

# Configuration
PEP_DIR="docs/peps"
BLOG_DIR="docs/blogs"
TEMPLATE_DIR="docs/templates"
CONFIG_FILE=".peprc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Source configuration if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "DEBUG")
            if [ "$DEBUG" = "true" ]; then
                echo -e "${BLUE}[DEBUG]${NC} $message"
            fi
            ;;
    esac
}

# Ensure required directories exist
ensure_directories() {
    for dir in "$PEP_DIR" "$BLOG_DIR" "$TEMPLATE_DIR" "tools/git-hooks"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log "INFO" "Created directory: $dir"
        fi
    done
}

# Get next available PEP number
get_next_pep_number() {
    local max_num=0
    
    if [ -d "$PEP_DIR" ] && [ "$(ls -A $PEP_DIR/pep-*.md 2>/dev/null)" ]; then
        for pep in $PEP_DIR/pep-*.md; do
            if [ -f "$pep" ]; then
                local num=$(basename "$pep" | sed 's/pep-\([0-9]*\)-.*/\1/' | sed 's/^0*//')
                if [ "$num" -gt "$max_num" ]; then
                    max_num="$num"
                fi
            fi
        done
    fi
    
    echo $((max_num + 1))
}

# Get next available BLOG number
get_next_blog_number() {
    local max_num=0
    
    if [ -d "$BLOG_DIR" ] && [ "$(ls -A $BLOG_DIR/blog-*.md 2>/dev/null)" ]; then
        for blog in $BLOG_DIR/blog-*.md; do
            if [ -f "$blog" ]; then
                local num=$(basename "$blog" | sed 's/blog-\([0-9]*\)-.*/\1/' | sed 's/^0*//')
                if [ "$num" -gt "$max_num" ]; then
                    max_num="$num"
                fi
            fi
        done
    fi
    
    echo $((max_num + 1))
}

# Create a new PEP
create_pep() {
    local pep_num=""
    local title=""
    local open_code=false
    
    # Check for --code flag and remove it from arguments
    local args=()
    for arg in "$@"; do
        if [ "$arg" = "--code" ]; then
            open_code=true
        else
            args+=("$arg")
        fi
    done
    
    # Parse remaining arguments intelligently
    local argc=${#args[@]}
    
    if [ $argc -eq 0 ]; then
        # No arguments - prompt for title and auto-number
        pep_num=$(get_next_pep_number)
        log "INFO" "Auto-assigned PEP number: $pep_num"
        echo -n "Enter PEP title: "
        read -r title
    elif [ $argc -eq 1 ]; then
        # One argument - check if it's a number or title
        if [[ "${args[0]}" =~ ^[0-9]+$ ]]; then
            # It's a number, prompt for title
            pep_num="${args[0]}"
            echo -n "Enter PEP title: "
            read -r title
        else
            # It's a title, auto-assign number
            title="${args[0]}"
            pep_num=$(get_next_pep_number)
            log "INFO" "Auto-assigned PEP number: $pep_num"
        fi
    elif [ $argc -eq 2 ]; then
        # Two arguments - first should be number, second title
        if [[ "${args[0]}" =~ ^[0-9]+$ ]]; then
            pep_num="${args[0]}"
            title="${args[1]}"
        else
            log "ERROR" "When providing two arguments, first must be a number"
            log "INFO" "Usage: $0 new-pep [--code] [number] [title]"
            exit 1
        fi
    else
        log "ERROR" "Too many arguments"
        log "INFO" "Usage: $0 new-pep [--code] [number] [title]"
        exit 1
    fi
    
    if [ -z "$title" ]; then
        log "ERROR" "Title is required"
        exit 1
    fi
    
    # Create slug from title (more robust)
    local slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    local filename="${PEP_DIR}/pep-$(printf "%03d" "$pep_num")-${slug}.md"
    
    if [ -f "$filename" ]; then
        log "ERROR" "PEP $pep_num already exists: $filename"
        exit 1
    fi
    
    ensure_directories
    
    if [ ! -f "${TEMPLATE_DIR}/pep-template.md" ]; then
        log "ERROR" "PEP template not found: ${TEMPLATE_DIR}/pep-template.md"
        log "INFO" "Run '$0 init' to create templates"
        exit 1
    fi
    
    # Copy template and replace placeholders
    cp "${TEMPLATE_DIR}/pep-template.md" "$filename"
    
    # Replace placeholders
    local author="${PEP_AUTHOR:-$(git config user.name 2>/dev/null || echo 'Unknown Author')}"
    local today=$(date +%Y-%m-%d)
    
    # Use different delimiter for sed to avoid conflicts with slashes and spaces
    sed -i.bak "s|XXX|$(printf "%03d" "$pep_num")|g" "$filename"
    sed -i.bak "s|\[Title\]|$title|g" "$filename"
    sed -i.bak "s|YYYY-MM-DD|$today|g" "$filename"
    sed -i.bak "s|\[Your Name\]|$author|g" "$filename"
    
    # Remove backup files
    rm -f "$filename.bak"
    
    log "INFO" "Created PEP-$(printf "%03d" "$pep_num"): $filename"
    
    # Handle editor opening based on flags and configuration
    if [ "$open_code" = true ]; then
        if command -v code >/dev/null 2>&1; then
            log "INFO" "Opening in VS Code..."
            code "$filename"
        else
            log "WARN" "VS Code not found, please install 'code' command"
            log "INFO" "Edit with: code $filename"
        fi
    elif [ "${AUTO_OPEN_EDITOR:-false}" = "true" ] && command -v "${EDITOR:-vi}" >/dev/null 2>&1; then
        log "INFO" "Opening in ${EDITOR:-vi}..."
        "${EDITOR:-vi}" "$filename"
    else
        log "INFO" "Edit with: code $filename"
        log "INFO" "Or use: $0 new-pep --code 'Title' to open in VS Code"
        log "INFO" "Or set AUTO_OPEN_EDITOR=true in .peprc to auto-open"
    fi
}

# Create a new BLOG
create_blog() {
    local blog_num="$1"
    local pep_num="$2"
    
    if [ -z "$pep_num" ]; then
        echo -n "Enter PEP number for this blog: "
        read -r pep_num
    fi
    
    if [ -z "$blog_num" ]; then
        blog_num=$(get_next_blog_number)
        log "INFO" "Auto-assigned BLOG number: $blog_num"
    fi
    
    if [ -z "$pep_num" ]; then
        log "ERROR" "PEP number is required"
        exit 1
    fi
    
    # Verify PEP exists
    local pep_files=($PEP_DIR/pep-$(printf "%03d" "$pep_num")-*.md)
    if [ ! -f "${pep_files[0]}" ]; then
        log "ERROR" "PEP-$(printf "%03d" "$pep_num") does not exist"
        exit 1
    fi
    
    local filename="${BLOG_DIR}/blog-$(printf "%03d" "$blog_num")-pep-$(printf "%03d" "$pep_num")-implementation.md"
    
    ensure_directories
    
    if [ ! -f "${TEMPLATE_DIR}/blog-template.md" ]; then
        log "ERROR" "BLOG template not found: ${TEMPLATE_DIR}/blog-template.md"
        exit 1
    fi
    
    # Copy template and replace placeholders
    cp "${TEMPLATE_DIR}/blog-template.md" "$filename"
    
    local author="${PEP_AUTHOR:-$(git config user.name 2>/dev/null || echo 'Unknown Author')}"
    local today=$(date +%Y-%m-%d)
    
    sed -i "s/XXX/$(printf "%03d" "$blog_num")/g" "$filename"
    sed -i "s/PEP-XXX/PEP-$(printf "%03d" "$pep_num")/g" "$filename"
    sed -i "s/YYYY-MM-DD/$today/g" "$filename"
    sed -i "s/\[Your Name\]/$author/g" "$filename"
    
    log "INFO" "Created BLOG-$(printf "%03d" "$blog_num"): $filename"
    
    # Only open editor if explicitly configured to do so
    if [ "${AUTO_OPEN_EDITOR:-false}" = "true" ] && command -v "${EDITOR:-vi}" >/dev/null 2>&1; then
        "${EDITOR:-vi}" "$filename"
    else
        log "INFO" "Edit with: code $filename"
        log "INFO" "Or set AUTO_OPEN_EDITOR=true in .peprc to auto-open"
    fi
}

# List all PEPs
list_peps() {
    if [ ! -d "$PEP_DIR" ]; then
        log "WARN" "PEP directory does not exist: $PEP_DIR"
        return
    fi
    
    echo -e "${BLUE}Project Enhancement Packages:${NC}"
    echo "=============================="
    
    local found=false
    for pep in $PEP_DIR/pep-*.md; do
        if [ -f "$pep" ]; then
            found=true
            local num=$(basename "$pep" | sed 's/pep-\([0-9]*\)-.*/\1/')
            local title=$(grep "^**Title:**" "$pep" | sed 's/**Title:** //' | head -1)
            local status=$(grep "^**Status:**" "$pep" | sed 's/**Status:** //' | head -1)
            local author=$(grep "^**Author:**" "$pep" | sed 's/**Author:** //' | head -1)
            
            case "$status" in
                "Draft")
                    status_color="${YELLOW}$status${NC}"
                    ;;
                "Active")
                    status_color="${BLUE}$status${NC}"
                    ;;
                "Implemented")
                    status_color="${GREEN}$status${NC}"
                    ;;
                "Rejected")
                    status_color="${RED}$status${NC}"
                    ;;
                *)
                    status_color="$status"
                    ;;
            esac
            
            printf "PEP-%s: %-40s [%s] by %s\n" "$num" "$title" "$status_color" "$author"
        fi
    done
    
    if [ "$found" = false ]; then
        echo "No PEPs found."
    fi
}

# Show status summary
show_status() {
    if [ ! -d "$PEP_DIR" ]; then
        log "WARN" "PEP directory does not exist: $PEP_DIR"
        return
    fi
    
    echo -e "${BLUE}PEP Status Summary:${NC}"
    echo "==================="
    
    local total=0
    for status in Draft Active Implemented Rejected Superseded; do
        local count=$(grep -l "^**Status:** $status" $PEP_DIR/pep-*.md 2>/dev/null | wc -l)
        printf "%-12s: %d\n" "$status" "$count"
        total=$((total + count))
    done
    
    echo "-------------"
    printf "%-12s: %d\n" "Total" "$total"
}

# Initialize PEP framework in current directory
init_framework() {
    log "INFO" "Initializing PEP framework..."
    
    ensure_directories
    
    # Create .peprc if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
# PEP Configuration
PEP_AUTHOR="$(git config user.name 2>/dev/null || echo 'Your Name')"
DEFAULT_EDITOR="vi"
PROJECT_NAME="$(basename "$(pwd)")"

# Integration settings
ZABBIX_HOST=""
GRAFANA_URL=""

# Notification settings (optional)
SLACK_WEBHOOK=""
EMAIL_NOTIFICATIONS="false"

# Debug mode
DEBUG="false"
EOF
        log "INFO" "Created configuration file: $CONFIG_FILE"
    fi
    
    # Create templates if they don't exist
    create_templates
    
    # Create git hooks
    setup_git_hooks
    
    log "INFO" "PEP framework initialized successfully!"
    log "INFO" "Edit $CONFIG_FILE to customize settings"
    log "INFO" "Create your first PEP with: $0 new-pep 'Project Foundation'"
}

# Create template files
create_templates() {
    if [ ! -f "${TEMPLATE_DIR}/pep-template.md" ]; then
        log "ERROR" "PEP template should be created manually or via cookiecutter"
        log "INFO" "See README.md for template content"
    fi
    
    if [ ! -f "${TEMPLATE_DIR}/blog-template.md" ]; then
        log "ERROR" "BLOG template should be created manually or via cookiecutter"
        log "INFO" "See README.md for template content"
    fi
}

# Setup git hooks
setup_git_hooks() {
    local hook_file=".git/hooks/commit-msg"
    local source_hook="tools/git-hooks/commit-msg"
    
    if [ ! -f "$source_hook" ]; then
        log "WARN" "Git hook source not found: $source_hook"
        return
    fi
    
    if [ -d ".git" ]; then
        cp "$source_hook" "$hook_file"
        chmod +x "$hook_file"
        log "INFO" "Installed git commit-msg hook"
    else
        log "WARN" "Not in a git repository, skipping hook installation"
    fi
}

# Show help
show_help() {
    cat << EOF
${BLUE}PEP Management Tool${NC}
===================

${GREEN}Usage:${NC} $0 <command> [arguments]

${GREEN}Commands:${NC}
  ${YELLOW}init${NC}                           Initialize PEP framework in current directory
  ${YELLOW}new-pep${NC} [number] [title]       Create a new PEP (auto-numbers if not specified)
  ${YELLOW}new-blog${NC} [blog-num] [pep-num]  Create implementation blog for PEP
  ${YELLOW}list${NC}                           List all PEPs with status
  ${YELLOW}status${NC}                         Show status summary
  ${YELLOW}help${NC}                           Show this help message

${GREEN}Examples:${NC}
  $0 init
  $0 new-pep "Nutanix Integration"
  $0 new-pep 5 "Nutanix Integration"
  $0 new-blog 3 5
  $0 list
  $0 status

${GREEN}Configuration:${NC}
  Edit ${YELLOW}.peprc${NC} to customize author, editor, and other settings.

${GREEN}Git Integration:${NC}
  Use branch naming: ${YELLOW}feature/pep-XXX-description${NC}
  Commit messages: ${YELLOW}pep-XXX: description${NC}
EOF
}

# Main script logic
main() {
    case "${1:-help}" in
        "init")
            init_framework
            ;;
        "new-pep")
            shift  # Remove 'new-pep' from arguments
            create_pep "$@"  # Pass all remaining arguments
            ;;
        "new-blog")
            create_blog "$2" "$3"
            ;;
        "list")
            list_peps
            ;;
        "status")
            show_status
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log "ERROR" "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"