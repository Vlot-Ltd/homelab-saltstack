#!/bin/bash
# PEP Management Tools
# Version: 2.1
# Description: Command-line tools for managing Project Enhancement Packages

set -e

# Configuration
PEP_DIR="docs/peps"
BLOG_DIR="docs/blogs"
TEMPLATE_DIR="docs/templates"
CONFIG_FILE=".peprc"

# Fallback source for update-tools/update-templates when no --source flag or
# PEP_FRAMEWORK_SOURCE is configured — lets those commands work out of the box
# on any machine, without a local checkout of the cookiecutter repo.
DEFAULT_TEMPLATE_REPO="https://github.com/belnarlo/pep-framework-cookiecutter.git"

# Colors for output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color

# Source configuration: project-level first, then personal overrides
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi
if [ -f "${CONFIG_FILE}.local" ]; then
    source "${CONFIG_FILE}.local"
fi

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"

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

# Returns the lowercase file prefix used in filenames (e.g. "pep-pe-mon-" or "pep-")
# Filenames: pep-pe-mon-001-feat-slug.md  /  pep-001-feat-slug.md
get_file_prefix() {
    local project="${PROJECT_CODE:-}"
    local repo="${REPO_CODE:-}"

    if [ -n "$project" ] && [ -n "$repo" ]; then
        echo "pep-$(echo "${project}-${repo}" | tr '[:upper:]' '[:lower:]')-"
    elif [ -n "$repo" ]; then
        echo "pep-$(echo "$repo" | tr '[:upper:]' '[:lower:]')-"
    elif [ -n "$project" ]; then
        echo "pep-$(echo "$project" | tr '[:upper:]' '[:lower:]')-"
    else
        echo "pep-"
    fi
}

# Returns the display ID used in file content, list, and commit messages
# e.g. "PEP-PE-MON-001"  /  "PEP-001"
get_pep_id() {
    local num="$1"
    local project="${PROJECT_CODE:-}"
    local repo="${REPO_CODE:-}"

    if [ -n "$project" ] && [ -n "$repo" ]; then
        printf "PEP-%s-%s-%03d" "$project" "$repo" "$((10#$num))"
    elif [ -n "$repo" ]; then
        printf "PEP-%s-%03d" "$repo" "$((10#$num))"
    elif [ -n "$project" ]; then
        printf "PEP-%s-%03d" "$project" "$((10#$num))"
    else
        printf "PEP-%03d" "$((10#$num))"
    fi
}

# Maps a PEP type name to a short slug used in filenames
get_type_slug() {
    case "$1" in
        "Project")        echo "proj" ;;
        "Feature")        echo "feat" ;;
        "Process")        echo "proc" ;;
        "Infrastructure") echo "infra" ;;
        "Documentation")  echo "docs" ;;
        "Bug")            echo "bug" ;;
        "Enhancement")    echo "enh" ;;
        "Research")       echo "research" ;;
        "Security")       echo "sec" ;;
        "Performance")    echo "perf" ;;
        *)                echo "$(echo "$1" | tr '[:upper:]' '[:lower:]' | cut -c1-8)" ;;
    esac
}

# Extract a metadata field from a PEP file, e.g. get_pep_field "$file" "Status"
# Trailing whitespace is stripped — template lines end in two spaces (a markdown
# line break), which would otherwise silently break status/date comparisons.
get_pep_field() {
    local file="$1" field="$2"
    grep "^\*\*${field}:\*\*" "$file" 2>/dev/null | sed "s|^\*\*${field}:\*\* *||; s/\r$//; s/[[:space:]]*$//" | head -1
}

# Extract the abstract paragraph — the first non-blank line after "## Abstract"
get_pep_abstract() {
    local file="$1"
    awk '/^## Abstract[[:space:]]*$/{flag=1; next} /^## /{flag=0} flag && NF {print; exit}' "$file" 2>/dev/null | sed 's/\r$//; s/[[:space:]]*$//'
}

# Extract the zero-padded 3-digit PEP number from a PEP filename
get_pep_num_from_file() {
    basename "$1" | grep -oE '[0-9]{3}' | head -1
}

# Number of days between a YYYY-MM-DD date and today. Portable across BSD date
# (macOS) and GNU date (Linux). Echoes nothing if the date is empty/unparseable,
# so callers can treat "unknown age" as "don't collapse it".
days_since() {
    local d="$1"
    [ -z "$d" ] && return
    local epoch
    epoch=$(date -j -f "%Y-%m-%d" "$d" "+%s" 2>/dev/null) || epoch=$(date -d "$d" "+%s" 2>/dev/null)
    [ -z "$epoch" ] && return
    echo $(( ( $(date "+%s") - epoch ) / 86400 ))
}

# Ensure required directories exist
ensure_directories() {
    local dirs=("$PEP_DIR" "$TEMPLATE_DIR" "tools/git-hooks")
    if [ "${ENABLE_BLOGS:-y}" = "y" ]; then
        dirs+=("$BLOG_DIR")
    fi
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log "INFO" "Created directory: $dir"
        fi
    done
}

# Remove blog scaffolding (docs/blogs, blog-template.md) when the feature is
# disabled — covers projects generated before this cleanup existed, or where
# ENABLE_BLOGS was flipped to "n" in .peprc after the fact. Run via init.
cleanup_blog_artifacts() {
    if [ "${ENABLE_BLOGS:-y}" = "y" ]; then
        return
    fi

    if [ -d "$BLOG_DIR" ]; then
        if [ -z "$(find "$BLOG_DIR" -mindepth 1 ! -name '.gitkeep' 2>/dev/null)" ]; then
            rm -rf "$BLOG_DIR"
            log "INFO" "Removed $BLOG_DIR (blogs feature disabled)"
        else
            log "WARN" "$BLOG_DIR is not empty, leaving it in place despite blogs being disabled"
        fi
    fi

    local blog_template="${TEMPLATE_DIR}/blog-template.md"
    if [ -f "$blog_template" ]; then
        rm -f "$blog_template"
        log "INFO" "Removed $blog_template (blogs feature disabled)"
    fi
}

# Get next available PEP number (extracts the first 3-digit group from each filename)
get_next_pep_number() {
    local max_num=0

    if [ -d "$PEP_DIR" ]; then
        for pep in "$PEP_DIR"/pep-*.md; do
            [ -f "$pep" ] || continue
            local num
            num=$(basename "$pep" | grep -oE '[0-9]{3}' | head -1 | sed 's/^0*//')
            if [ -n "$num" ] && [ "$num" -gt "$max_num" ] 2>/dev/null; then
                max_num="$num"
            fi
        done
    fi

    # Also consider every local and remote branch (read-only), so two branches
    # don't both raise the same number. Remote refs are as of the last fetch.
    local ref_max
    ref_max=$(get_max_pep_number_in_refs)
    if [ "$ref_max" -gt "$max_num" ]; then
        log "INFO" "Highest PEP number on other branches: $ref_max (last fetched state)" >&2
        max_num="$ref_max"
    fi

    echo $((max_num + 1))
}

# Highest PEP number for this repo's prefix across refs/heads and refs/remotes.
# Read-only: git for-each-ref + git ls-tree, no fetch, no checkout. Identical
# trees are listed once. Prints 0 outside a git repo or when nothing matches.
get_max_pep_number_in_refs() {
    local max=0 tree path num file_prefix
    file_prefix=$(get_file_prefix)

    git rev-parse --git-dir >/dev/null 2>&1 || { echo 0; return; }

    while IFS= read -r tree; do
        [ -n "$tree" ] || continue
        while IFS= read -r path; do
            path="${path##*/}"
            if [[ "$path" =~ ^${file_prefix}([0-9]{3})- ]]; then
                num=$((10#${BASH_REMATCH[1]}))
                [ "$num" -gt "$max" ] && max="$num"
            fi
        done < <(git ls-tree --name-only "$tree" "${PEP_DIR}/" 2>/dev/null)
    done < <(git for-each-ref --format='%(tree)' refs/heads refs/remotes 2>/dev/null | sort -u)

    echo "$max"
}

# Escape a string for use as a sed replacement with | as the delimiter
sed_escape() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

# Get next available BLOG number
get_next_blog_number() {
    local max_num=0

    if [ -d "$BLOG_DIR" ]; then
        for blog in "$BLOG_DIR"/blog-*.md; do
            [ -f "$blog" ] || continue
            local num
            num=$(basename "$blog" | grep -oE '[0-9]{3}' | head -1 | sed 's/^0*//')
            if [ -n "$num" ] && [ "$num" -gt "$max_num" ] 2>/dev/null; then
                max_num="$num"
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
    local no_open=false
    local flag_type="" flag_priority="" flag_abstract="" have_abstract=false

    local args=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --code)      open_code=true; shift ;;
            --no-open)   no_open=true; shift ;;
            --type|--priority|--abstract)
                if [ $# -lt 2 ]; then
                    log "ERROR" "$1 requires a value"
                    exit 1
                fi
                case "$1" in
                    --type)     flag_type="$2" ;;
                    --priority) flag_priority="$2" ;;
                    --abstract) flag_abstract="$2"; have_abstract=true ;;
                esac
                shift 2 ;;
            --type=*)     flag_type="${1#*=}"; shift ;;
            --priority=*) flag_priority="${1#*=}"; shift ;;
            --abstract=*) flag_abstract="${1#*=}"; have_abstract=true; shift ;;
            *)           args+=("$1"); shift ;;
        esac
    done

    local argc=${#args[@]}

    if [ $argc -eq 0 ]; then
        pep_num=$(get_next_pep_number)
        log "INFO" "Auto-assigned PEP number: $pep_num"
        echo -n "Enter PEP title: "
        read -r title || true
    elif [ $argc -eq 1 ]; then
        if [[ "${args[0]}" =~ ^[0-9]+$ ]]; then
            pep_num="${args[0]}"
            echo -n "Enter PEP title: "
            read -r title || true
        else
            title="${args[0]}"
            pep_num=$(get_next_pep_number)
            log "INFO" "Auto-assigned PEP number: $pep_num"
        fi
    elif [ $argc -eq 2 ]; then
        if [[ "${args[0]}" =~ ^[0-9]+$ ]]; then
            pep_num="${args[0]}"
            title="${args[1]}"
        else
            log "ERROR" "When providing two arguments, first must be a number"
            log "INFO" "Usage: $0 new-pep [--code] [--no-open] [--type T] [--priority P] [--abstract TEXT] [number] [title]"
            exit 1
        fi
    else
        log "ERROR" "Too many arguments"
        log "INFO" "Usage: $0 new-pep [--code] [--no-open] [--type T] [--priority P] [--abstract TEXT] [number] [title]"
        exit 1
    fi

    if [ -z "$title" ]; then
        log "ERROR" "Title is required"
        exit 1
    fi

    # Type: --type (name or number) or prompt
    local pep_types=("Project" "Feature" "Process" "Infrastructure" "Documentation" "Bug" "Enhancement" "Research" "Security" "Performance")
    local pep_type=""
    if [ -n "$flag_type" ]; then
        if [[ "$flag_type" =~ ^[0-9]+$ ]] && [ "$flag_type" -ge 1 ] && [ "$flag_type" -le "${#pep_types[@]}" ]; then
            pep_type="${pep_types[$((flag_type-1))]}"
        else
            local t
            for t in "${pep_types[@]}"; do
                if [ "$(echo "$t" | tr '[:upper:]' '[:lower:]')" = "$(echo "$flag_type" | tr '[:upper:]' '[:lower:]')" ]; then
                    pep_type="$t"
                fi
            done
        fi
        if [ -z "$pep_type" ]; then
            log "ERROR" "Unknown --type '$flag_type' (valid: ${pep_types[*]})"
            exit 1
        fi
    else
        echo ""
        echo "Select PEP type:"
        for i in "${!pep_types[@]}"; do
            printf "  %2d) %s\n" "$((i+1))" "${pep_types[$i]}"
        done
        echo -n "Type [1-${#pep_types[@]}, default 2 (Feature)]: "
        read -r type_choice || true
        if [[ "$type_choice" =~ ^[0-9]+$ ]] && [ "$type_choice" -ge 1 ] && [ "$type_choice" -le "${#pep_types[@]}" ]; then
            pep_type="${pep_types[$((type_choice-1))]}"
        else
            pep_type="Feature"
            log "INFO" "Defaulting to type: $pep_type"
        fi
    fi

    # Priority: --priority or prompt
    local pep_priority priority_choice
    if [ -n "$flag_priority" ]; then
        priority_choice="$flag_priority"
    else
        echo -n "Priority [H)igh / M)edium / L)ow, default M]: "
        read -r priority_choice || true
    fi
    priority_choice="$(echo "$priority_choice" | tr '[:upper:]' '[:lower:]')"
    case "$priority_choice" in
        h|high)        pep_priority="High" ;;
        l|low)         pep_priority="Low" ;;
        m|medium|"")   pep_priority="Medium" ;;
        *)
            if [ -n "$flag_priority" ]; then
                log "ERROR" "Unknown --priority '$flag_priority' (valid: High, Medium, Low)"
                exit 1
            fi
            pep_priority="Medium" ;;
    esac

    # Abstract: --abstract or prompt
    local pep_abstract
    if [ "$have_abstract" = true ]; then
        pep_abstract="$flag_abstract"
    else
        echo -n "Brief abstract (2-3 sentences): "
        read -r pep_abstract || true
    fi

    # Build filename: {prefix}{num}-{typeslug}-{titleslug}.md
    local type_slug
    type_slug=$(get_type_slug "$pep_type")
    local title_slug
    title_slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    local file_prefix
    file_prefix=$(get_file_prefix)
    local filename="${PEP_DIR}/${file_prefix}$(printf "%03d" "$pep_num")-${type_slug}-${title_slug}.md"

    if [ -f "$filename" ]; then
        log "ERROR" "PEP $pep_num already exists: $filename"
        exit 1
    fi

    ensure_directories

    if [ ! -f "${TEMPLATE_DIR}/pep-template.md" ]; then
        log "ERROR" "PEP template not found: ${TEMPLATE_DIR}/pep-template.md"
        log "INFO" "Run '$0 update-templates' to pull templates from source"
        exit 1
    fi

    cp "${TEMPLATE_DIR}/pep-template.md" "$filename"

    local author="${PEP_AUTHOR:-$(git config user.name 2>/dev/null || echo 'Unknown Author')}"
    local today
    today=$(date +%Y-%m-%d)
    local pep_id
    pep_id=$(get_pep_id "$pep_num")

    sed -i.bak "s|PEPID|$pep_id|g" "$filename"
    sed -i.bak "s|\[Title\]|$(sed_escape "$title")|g" "$filename"
    sed -i.bak "s|YYYY-MM-DD|$today|g" "$filename"
    sed -i.bak "s|\[Your Name\]|$(sed_escape "$author")|g" "$filename"
    sed -i.bak "s|\[Type\]|$pep_type|g" "$filename"
    sed -i.bak "s|\[Priority\]|$pep_priority|g" "$filename"
    if [ -n "$pep_abstract" ]; then
        sed -i.bak "s|Brief summary of the enhancement (2-3 sentences).|$(sed_escape "$pep_abstract")|" "$filename"
    fi

    rm -f "$filename.bak"

    log "INFO" "Created $pep_id: $filename"

    if [ "$no_open" = true ]; then
        :  # --no-open: never launch an editor (scripted use)
    elif [ "$open_code" = true ]; then
        if command -v code >/dev/null 2>&1; then
            log "INFO" "Opening in VS Code..."
            code "$filename"
        else
            log "WARN" "VS Code not found"
            log "INFO" "Edit with: code $filename"
        fi
    elif [ "${AUTO_OPEN_EDITOR:-false}" = "true" ] && [ -t 0 ] && [ -t 1 ] && command -v "${DEFAULT_EDITOR:-vi}" >/dev/null 2>&1; then
        log "INFO" "Opening in ${DEFAULT_EDITOR:-vi}..."
        "${DEFAULT_EDITOR:-vi}" "$filename"
    else
        log "INFO" "Edit with: ${DEFAULT_EDITOR:-code} $filename"
        if [ "${BRANCH_PER_PEP:-true}" = "true" ]; then
            log "INFO" "Create branch when ready: $0 new-branch $pep_num"
        fi
    fi
}

# Create a git feature branch for a PEP
new_branch() {
    local pep_ref=""
    local stay="false"
    [ "${BRANCH_PER_PEP:-true}" = "true" ] || stay="true"

    while [ $# -gt 0 ]; do
        case "$1" in
            --here|--stay) stay="true"; shift ;;
            *) [ -z "$pep_ref" ] && pep_ref="$1"; shift ;;
        esac
    done

    if [ -z "$pep_ref" ]; then
        echo -n "Enter PEP number or ID (e.g. 3 or PEP-PE-MON-003): "
        read -r pep_ref
    fi

    local pep_num
    pep_num=$(echo "$pep_ref" | grep -oE '[0-9]+$' | head -1)

    if [ -z "$pep_num" ]; then
        log "ERROR" "Could not parse PEP number from: $pep_ref"
        exit 1
    fi

    local file_prefix
    file_prefix=$(get_file_prefix)
    local pep_padded
    pep_padded=$(printf "%03d" "$((10#$pep_num))")
    local pep_files=("$PEP_DIR"/${file_prefix}${pep_padded}-*.md)

    if [ ! -f "${pep_files[0]}" ]; then
        log "ERROR" "PEP ${pep_padded} not found (looked for ${file_prefix}${pep_padded}-*.md)"
        exit 1
    fi

    if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
        log "ERROR" "Not in a git repository"
        exit 1
    fi

    # Stay mode: BRANCH_PER_PEP=false in .peprc, or --here for a one-off
    if [ "$stay" = "true" ]; then
        log "INFO" "Staying on branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
        log "INFO" "Commit with: $0 commit $pep_num \"message\""
        return 0
    fi

    # Branch name mirrors the filename: feature/pep-pe-mon-003-feat-slug
    local branch_name
    branch_name="feature/$(basename "${pep_files[0]}" .md)"

    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        log "WARN" "Branch already exists: $branch_name"
        echo -n "Switch to it? [Y/n]: "
        read -r response
        response="$(echo "$response" | tr '[:upper:]' '[:lower:]')"
        if [[ ! "$response" =~ ^n ]]; then
            git checkout "$branch_name"
            log "INFO" "Switched to: $branch_name"
        fi
    else
        git checkout -b "$branch_name"
        log "INFO" "Created and switched to: $branch_name"
    fi
}

# Commit staged changes (or the PEP file itself) with the correct message format
commit_pep() {
    local pep_ref="${1:-}"

    # Collect all remaining args as the message
    if [ $# -ge 2 ]; then
        shift
        local message="$*"
    else
        local message=""
    fi

    if [ -z "$pep_ref" ]; then
        echo -n "Enter PEP number or ID (e.g. 3 or PEP-PE-MON-003): "
        read -r pep_ref
    fi

    local pep_num
    pep_num=$(echo "$pep_ref" | grep -oE '[0-9]+$' | head -1)

    if [ -z "$pep_num" ]; then
        log "ERROR" "Could not parse PEP number from: $pep_ref"
        exit 1
    fi

    if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
        log "ERROR" "Not in a git repository"
        exit 1
    fi

    local file_prefix
    file_prefix=$(get_file_prefix)
    local pep_padded
    pep_padded=$(printf "%03d" "$((10#$pep_num))")
    local pep_files=("$PEP_DIR"/${file_prefix}${pep_padded}-*.md)

    if [ ! -f "${pep_files[0]}" ]; then
        log "ERROR" "PEP ${pep_padded} not found"
        exit 1
    fi

    if [ -z "$message" ]; then
        echo -n "Commit message (prefix '${file_prefix}${pep_padded}: ' will be added): "
        read -r message
    fi

    if [ -z "$message" ]; then
        log "ERROR" "Message is required"
        exit 1
    fi

    # If nothing staged, auto-stage the PEP file
    if git diff --cached --quiet 2>/dev/null; then
        log "INFO" "Nothing staged — staging ${pep_files[0]}"
        git add "${pep_files[0]}"
    fi

    local full_message="${file_prefix}${pep_padded}: $message"
    git commit -m "$full_message"
    log "INFO" "Committed: $full_message"
}

# Migrate existing PEPs to the current naming scheme
migrate_peps() {
    local dry_run=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            *) log "ERROR" "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ ! -d "$PEP_DIR" ]; then
        log "WARN" "PEP directory not found: $PEP_DIR"
        return
    fi

    local file_prefix
    file_prefix=$(get_file_prefix)

    # Known type slugs — used to detect already-typed filenames
    local type_slugs=("proj" "feat" "proc" "infra" "docs" "bug" "enh" "research" "sec" "perf")

    local migrated=0 skipped=0

    # Only scan files where the number appears right after "pep-" — that is the old format.
    # New-format files with codes (pep-pe-mon-NNN-...) don't match pep-[0-9][0-9][0-9]-* glob.
    for pep in "$PEP_DIR"/pep-[0-9][0-9][0-9]-*.md; do
        [ -f "$pep" ] || continue

        local basename_pep
        basename_pep=$(basename "$pep")
        local num
        num=$(echo "$basename_pep" | grep -oE '^pep-([0-9]{3})-' | grep -oE '[0-9]{3}')
        [ -z "$num" ] && continue

        local after_num
        after_num=$(echo "$basename_pep" | sed "s/^pep-${num}-//")  # everything after pep-NNN-

        # Check if the file already has a type slug prefix
        local has_type_slug=false
        local existing_type_slug=""
        for ts in "${type_slugs[@]}"; do
            if [[ "$after_num" == "${ts}-"* ]]; then
                has_type_slug=true
                existing_type_slug="$ts"
                break
            fi
        done

        # Skip if already in the target format for this repo
        if [ "$file_prefix" = "pep-" ] && $has_type_slug; then
            log "INFO" "Already up-to-date, skipping: $basename_pep"
            skipped=$((skipped + 1))
            continue
        fi

        # Read PEP metadata from content
        local title
        title=$(get_pep_field "$pep" "Title")
        local pep_type
        pep_type=$(get_pep_field "$pep" "Type")

        log "INFO" "Migrating: $basename_pep"
        [ -n "$title" ] && echo "  Title: $title"

        # Resolve type —————————————————————————————————————————————————
        if $has_type_slug && { [[ "$pep_type" == *"|"* ]] || [ -z "$pep_type" ]; }; then
            # Type slug is already in filename; map it back to a display name
            case "$existing_type_slug" in
                proj) pep_type="Project" ;; feat) pep_type="Feature" ;;
                proc) pep_type="Process" ;; infra) pep_type="Infrastructure" ;;
                docs) pep_type="Documentation" ;; bug) pep_type="Bug" ;;
                enh) pep_type="Enhancement" ;; research) pep_type="Research" ;;
                sec) pep_type="Security" ;; perf) pep_type="Performance" ;;
            esac
        elif [[ "$pep_type" == *"|"* ]] || [ -z "$pep_type" ]; then
            # Type not yet selected — prompt the user
            local pep_types_arr=("Project" "Feature" "Process" "Infrastructure" "Documentation" "Bug" "Enhancement" "Research" "Security" "Performance")
            echo "  Type unclear (content shows: ${pep_type:-none})"
            for i in "${!pep_types_arr[@]}"; do
                printf "    %2d) %s\n" "$((i+1))" "${pep_types_arr[$i]}"
            done
            echo -n "  Select type [1-${#pep_types_arr[@]}, default 2 (Feature)]: "
            read -r type_choice
            if [[ "$type_choice" =~ ^[0-9]+$ ]] && [ "$type_choice" -ge 1 ] && [ "$type_choice" -le "${#pep_types_arr[@]}" ]; then
                pep_type="${pep_types_arr[$((type_choice-1))]}"
            else
                pep_type="Feature"
            fi
        fi

        local final_type_slug
        final_type_slug=$(get_type_slug "$pep_type")

        # Build the title slug part (strip existing type slug if present)
        local title_slug
        title_slug="${after_num%.md}"
        if $has_type_slug; then
            title_slug="${title_slug#${existing_type_slug}-}"
        fi

        # New filename
        local new_filename="${PEP_DIR}/${file_prefix}${num}-${final_type_slug}-${title_slug}.md"
        local new_pep_id
        new_pep_id=$(get_pep_id "$((10#$num))")

        echo "  → $(basename "$new_filename")  (ID: $new_pep_id)"

        if $dry_run; then
            continue
        fi

        cp "$pep" "$new_filename"

        # Replace inline PEP-NNN references throughout the document FIRST, before
        # the targeted heading/ID substitutions below. With codes placed between
        # "PEP" and the number (PEP-CODES-NNN), new_pep_id no longer contains the
        # old "PEP-NNN" text as a substring, but keeping this global replace first
        # is still the safe order in case PROJECT_CODE/REPO_CODE are both unset
        # (new_pep_id == "PEP-NNN", i.e. an idempotent no-op replace).
        sed -i.bak "s|PEP-$(printf "%03d" "$((10#$num))")|${new_pep_id}|g" "$new_filename"
        # Update heading:  # PEP-001: Title  →  # PEP-PE-MON-001: Title
        # (no-op if the line above already rewrote it)
        sed -i.bak "s|^# PEP-${num}: |# ${new_pep_id}: |" "$new_filename"
        # Update **PEP:** NNN  →  **ID:** PEP-PE-MON-001
        sed -i.bak "s|^\*\*PEP:\*\* ${num}[[:space:]]*$|**ID:** ${new_pep_id}|" "$new_filename"
        # Replace any existing **ID:** line
        sed -i.bak "s|^\*\*ID:\*\*.*|**ID:** ${new_pep_id}|" "$new_filename"
        # Fix Type if still pipe-separated
        if grep -q "^\*\*Type:\*\*.*|" "$new_filename"; then
            sed -i.bak "s|^\*\*Type:\*\*.*|**Type:** ${pep_type}|" "$new_filename"
        fi
        # Add Priority after Type if missing (awk handles multi-line insertion portably)
        if ! grep -q "^\*\*Priority:\*\*" "$new_filename"; then
            awk '/^\*\*Type:\*\*/{print; print "**Priority:** Medium"; next}1' \
                "$new_filename" > "${new_filename}.tmp" && mv "${new_filename}.tmp" "$new_filename"
        fi

        rm -f "${new_filename}.bak"
        rm "$pep"

        migrated=$((migrated + 1))
        log "INFO" "  Done"
    done

    if [ $((migrated + skipped)) -eq 0 ]; then
        log "INFO" "No PEP files found to migrate"
        return
    fi

    if $dry_run; then
        log "INFO" "Dry run: $migrated would be migrated, $skipped already up-to-date"
    else
        log "INFO" "Done: $migrated migrated, $skipped already up-to-date"
        if [ "$migrated" -gt 0 ] && [ -d ".git" ]; then
            log "INFO" "Commit the changes: git add -A && git commit -m 'chore: migrate PEPs to new naming scheme'"
        fi
    fi
}

# Repair PEP docs written by the pre-fix get_pep_id(), which put the codes
# before the literal "PEP" (e.g. "PS-SLT-PEP-003" instead of "PEP-PS-SLT-003").
# Filenames were never affected — only the "**ID:**" line, the heading, and any
# other inline references inside the document content.
fix_naming() {
    local dry_run=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            *) log "ERROR" "Unknown option: $1"; log "INFO" "Usage: $0 fix-naming [--dry-run]"; exit 1 ;;
        esac
    done

    if [ ! -d "$PEP_DIR" ]; then
        log "WARN" "PEP directory not found: $PEP_DIR"
        return
    fi

    local project="${PROJECT_CODE:-}"
    local repo="${REPO_CODE:-}"

    if [ -z "$project" ] && [ -z "$repo" ]; then
        log "INFO" "No PROJECT_CODE/REPO_CODE configured — the old bug only affected IDs built from those codes. Nothing to fix."
        return
    fi

    # Match the broken pattern by regex rather than a fixed number, since
    # Supersedes/Superseded-By lines can reference a *different* PEP number
    # than the file's own — a single-number match would miss those.
    local broken_pattern replacement
    if [ -n "$project" ] && [ -n "$repo" ]; then
        broken_pattern="${project}-${repo}-PEP-([0-9]{3})"
        replacement="PEP-${project}-${repo}-\\1"
    elif [ -n "$repo" ]; then
        broken_pattern="${repo}-PEP-([0-9]{3})"
        replacement="PEP-${repo}-\\1"
    else
        broken_pattern="${project}-PEP-([0-9]{3})"
        replacement="PEP-${project}-\\1"
    fi

    local fixed=0 skipped=0

    for pep in "$PEP_DIR"/pep-*.md; do
        [ -f "$pep" ] || continue

        if ! grep -qE -- "$broken_pattern" "$pep"; then
            skipped=$((skipped + 1))
            continue
        fi

        local hits
        hits=$(grep -oE -- "$broken_pattern" "$pep" | sort -u | tr '\n' ' ')
        log "INFO" "$(basename "$pep"): $hits"

        if $dry_run; then
            fixed=$((fixed + 1))
            continue
        fi

        sed -i.bak -E "s|${broken_pattern}|${replacement}|g" "$pep"
        rm -f "${pep}.bak"
        fixed=$((fixed + 1))
    done

    if [ $((fixed + skipped)) -eq 0 ]; then
        log "INFO" "No PEP files found"
        return
    fi

    if $dry_run; then
        log "INFO" "Dry run: $fixed file(s) would be fixed, $skipped already correct"
    else
        log "INFO" "Done: $fixed file(s) fixed, $skipped already correct"
        if [ "$fixed" -gt 0 ] && [ -d ".git" ]; then
            log "INFO" "Review the changes then commit: git add -A && git commit -m 'chore: fix PEP ID naming order'"
        fi
    fi
}

# Create a new BLOG
create_blog() {
    if [ "${ENABLE_BLOGS:-y}" != "y" ]; then
        log "ERROR" "Blogs feature is disabled. Set ENABLE_BLOGS=y in .peprc to enable."
        exit 1
    fi

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

    local file_prefix
    file_prefix=$(get_file_prefix)
    local pep_files=("$PEP_DIR"/${file_prefix}$(printf "%03d" "$((10#$pep_num))")-*.md)
    if [ ! -f "${pep_files[0]}" ]; then
        log "ERROR" "PEP $(printf "%03d" "$((10#$pep_num))") does not exist"
        exit 1
    fi

    local filename="${BLOG_DIR}/blog-$(printf "%03d" "$blog_num")-pep-$(printf "%03d" "$pep_num")-implementation.md"

    ensure_directories

    if [ ! -f "${TEMPLATE_DIR}/blog-template.md" ]; then
        log "ERROR" "BLOG template not found: ${TEMPLATE_DIR}/blog-template.md"
        exit 1
    fi

    cp "${TEMPLATE_DIR}/blog-template.md" "$filename"

    local author="${PEP_AUTHOR:-$(git config user.name 2>/dev/null || echo 'Unknown Author')}"
    local today
    today=$(date +%Y-%m-%d)
    local pep_id
    pep_id=$(get_pep_id "$pep_num")

    sed -i "s/XXX/$(printf "%03d" "$blog_num")/g" "$filename"
    sed -i "s/PEPID/$pep_id/g" "$filename"
    sed -i "s/YYYY-MM-DD/$today/g" "$filename"
    sed -i "s/\[Your Name\]/$author/g" "$filename"

    log "INFO" "Created BLOG-$(printf "%03d" "$blog_num"): $filename"

    if [ "${AUTO_OPEN_EDITOR:-false}" = "true" ] && command -v "${DEFAULT_EDITOR:-vi}" >/dev/null 2>&1; then
        "${DEFAULT_EDITOR:-vi}" "$filename"
    else
        log "INFO" "Edit with: ${DEFAULT_EDITOR:-code} $filename"
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
    for pep in "$PEP_DIR"/pep-*.md; do
        [ -f "$pep" ] || continue
        found=true

        local raw_num
        raw_num=$(get_pep_num_from_file "$pep")
        local pep_id
        pep_id=$(get_pep_id "$((10#$raw_num))")

        local title
        title=$(get_pep_field "$pep" "Title")
        local status
        status=$(get_pep_field "$pep" "Status")
        local pep_type
        pep_type=$(get_pep_field "$pep" "Type")
        local author
        author=$(get_pep_field "$pep" "Author")

        local status_color
        case "$status" in
            "Draft")       status_color="${YELLOW}$status${NC}" ;;
            "Active")      status_color="${BLUE}$status${NC}" ;;
            "Implemented") status_color="${GREEN}$status${NC}" ;;
            "Rejected")    status_color="${RED}$status${NC}" ;;
            "Informational") status_color="${CYAN}$status${NC}" ;;
            *)             status_color="$status" ;;
        esac

        printf "%s [%s]: %-40s (%b) by %s\n" "$pep_id" "$pep_type" "$title" "$status_color" "$author"
    done

    if [ "$found" = false ]; then
        echo "No PEPs found."
    fi
}

# Show status summary, unexpected-status flags, grouped-by-status listing,
# and (with --since) a changes-since-date section — built for meeting prep.
show_status() {
    local since=""
    local show_all=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --since) since="$2"; shift 2 ;;
            --show-all) show_all=true; shift ;;
            *) log "ERROR" "Unknown option: $1"; log "INFO" "Usage: $0 status [--since YYYY-MM-DD] [--show-all]"; exit 1 ;;
        esac
    done

    if [ -n "$since" ] && ! [[ "$since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        log "ERROR" "--since expects a date in YYYY-MM-DD format"
        exit 1
    fi

    if [ ! -d "$PEP_DIR" ]; then
        log "WARN" "PEP directory does not exist: $PEP_DIR"
        return
    fi

    # Informational is a standing status (reference/guidance PEPs with no
    # implementation to finish) — neither open work nor closed. It is last so the
    # counts[] indexes used for the Open/Closed totals below stay valid.
    local known_statuses=("Draft" "Active" "Implemented" "Rejected" "Superseded" "Informational")

    local example_id
    example_id=$(get_pep_id 1)
    echo -e "${BLUE}PEP Status Summary (ID format: ${example_id%001}NNN):${NC}"
    echo "============================================="

    local total=0
    local counts=()
    for status in "${known_statuses[@]}"; do
        local count
        count=$(grep -rl "^\*\*Status:\*\* $status" "$PEP_DIR"/pep-*.md 2>/dev/null | wc -l | tr -d ' ')
        counts+=("$count")
        total=$((total + count))
    done

    local open_count=$((counts[0] + counts[1]))
    local closed_count=$((counts[2] + counts[3] + counts[4]))

    printf "%-30s: %d\n" "Open (Draft + Active)" "$open_count"
    for i in "${!known_statuses[@]}"; do
        printf "%-14s: %d\n" "${known_statuses[$i]}" "${counts[$i]}"
    done
    printf "%-30s: %d\n" "Closed (Implemented + Rejected + Superseded)" "$closed_count"
    printf "%-30s: %d\n" "Standing (Informational)" "${counts[5]}"

    echo "-------------"
    printf "%-14s: %d\n" "Total" "$total"

    # Flag PEPs whose status doesn't match one of the known values (typos, blank, etc.)
    local unexpected=()
    for pep in "$PEP_DIR"/pep-*.md; do
        [ -f "$pep" ] || continue
        local status
        status=$(get_pep_field "$pep" "Status")
        local known=false
        for k in "${known_statuses[@]}"; do
            if [ "$status" = "$k" ]; then
                known=true
                break
            fi
        done
        if [ "$known" = false ]; then
            unexpected+=("$pep")
        fi
    done

    if [ ${#unexpected[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}⚠ PEPs with unexpected or missing status (needs fixing):${NC}"
        for pep in "${unexpected[@]}"; do
            local num pep_id status
            num=$(get_pep_num_from_file "$pep")
            pep_id=$(get_pep_id "$((10#$num))")
            status=$(get_pep_field "$pep" "Status")
            printf "  %-20s %-20s %s\n" "$pep_id" "${status:-<none>}" "$pep"
        done
    fi

    # Grouped listing by status, with ID + title + abstract — formatted for
    # copy/paste directly into meeting notes.
    #
    # Closed statuses (Implemented/Rejected/Superseded) accumulate over the life
    # of a project, so by default we collapse ones closed a long time ago into a
    # summary line rather than listing them in full — --show-all disables this.
    local closed_collapse_days=60
    local terminal_statuses=("Implemented" "Rejected" "Superseded")

    echo ""
    echo -e "${BLUE}PEPs by Status${NC}"
    echo "=============="
    for status in "${known_statuses[@]}"; do
        local files=()
        for pep in "$PEP_DIR"/pep-*.md; do
            [ -f "$pep" ] || continue
            [ "$(get_pep_field "$pep" "Status")" = "$status" ] && files+=("$pep")
        done
        [ ${#files[@]} -eq 0 ] && continue

        local is_terminal=false
        for t in "${terminal_statuses[@]}"; do
            [ "$status" = "$t" ] && is_terminal=true && break
        done

        local shown=("${files[@]}")
        local old_count=0
        if [ "$is_terminal" = true ] && [ "$show_all" = false ]; then
            shown=()
            for pep in "${files[@]}"; do
                local upd age
                upd=$(get_pep_field "$pep" "Updated")
                age=$(days_since "$upd")
                if [ -n "$age" ] && [ "$age" -gt "$closed_collapse_days" ]; then
                    old_count=$((old_count + 1))
                else
                    shown+=("$pep")
                fi
            done
        fi

        echo ""
        if [ "$old_count" -gt 0 ]; then
            echo "## $status (${#files[@]}): ${#shown[@]} shown below, ${old_count} closed more than ${closed_collapse_days} days ago — run 'status --show-all' to list them."
        else
            echo "## $status (${#files[@]})"
        fi
        for pep in "${shown[@]}"; do
            local num pep_id title abstract
            num=$(get_pep_num_from_file "$pep")
            pep_id=$(get_pep_id "$((10#$num))")
            title=$(get_pep_field "$pep" "Title")
            abstract=$(get_pep_abstract "$pep")
            echo "- ${pep_id}: ${title}"
            [ -n "$abstract" ] && echo "    ${abstract}"
        done
    done

    # Changes since a given date — new PEPs, completed PEPs, and other updates.
    # Uses the Created/Updated fields already captured on every PEP; there's no
    # separate change log, so "completed"/"updated" are inferred from Status +
    # Updated date rather than a true history of status transitions.
    if [ -n "$since" ]; then
        echo ""
        echo -e "${BLUE}Changes since ${since}${NC}"
        echo "============================="

        local raised=() completed=() updated=()
        for pep in "$PEP_DIR"/pep-*.md; do
            [ -f "$pep" ] || continue
            local created upd status is_new is_terminal
            created=$(get_pep_field "$pep" "Created")
            upd=$(get_pep_field "$pep" "Updated")
            status=$(get_pep_field "$pep" "Status")

            is_new=false
            if [ -n "$created" ] && [[ ! "$created" < "$since" ]]; then
                raised+=("$pep")
                is_new=true
            fi

            is_terminal=false
            case "$status" in
                Implemented|Rejected|Superseded) is_terminal=true ;;
            esac

            if [ -n "$upd" ] && [[ ! "$upd" < "$since" ]] && [ "$is_new" = false ]; then
                if [ "$is_terminal" = true ]; then
                    completed+=("$pep")
                else
                    updated+=("$pep")
                fi
            fi
        done

        echo ""
        echo "New PEPs raised (${#raised[@]}):"
        if [ ${#raised[@]} -eq 0 ]; then
            echo "  None"
        else
            for status in "${known_statuses[@]}"; do
                local group=()
                for pep in "${raised[@]}"; do
                    [ "$(get_pep_field "$pep" "Status")" = "$status" ] && group+=("$pep")
                done
                [ ${#group[@]} -eq 0 ] && continue

                local sorted_lines
                sorted_lines=$(
                    for pep in "${group[@]}"; do
                        echo "$(get_pep_field "$pep" "Created")|${pep}"
                    done | sort
                )

                echo "  Now ${status} (${#group[@]}):"
                while IFS='|' read -r created pep; do
                    local num pep_id title
                    num=$(get_pep_num_from_file "$pep")
                    pep_id=$(get_pep_id "$((10#$num))")
                    title=$(get_pep_field "$pep" "Title")
                    echo "    - ${pep_id}: ${title} (created ${created})"
                done <<< "$sorted_lines"
            done
        fi

        echo ""
        echo "Completed — pre-existing PEPs closed (${#completed[@]}):"
        if [ ${#completed[@]} -eq 0 ]; then
            echo "  None"
        else
            for pep in "${completed[@]}"; do
                local num pep_id title status upd
                num=$(get_pep_num_from_file "$pep")
                pep_id=$(get_pep_id "$((10#$num))")
                title=$(get_pep_field "$pep" "Title")
                status=$(get_pep_field "$pep" "Status")
                upd=$(get_pep_field "$pep" "Updated")
                echo "  - ${pep_id}: ${title} — now ${status} (updated ${upd})"
            done
        fi

        echo ""
        echo "Other updates (${#updated[@]}):"
        if [ ${#updated[@]} -eq 0 ]; then
            echo "  None"
        else
            for pep in "${updated[@]}"; do
                local num pep_id title status upd
                num=$(get_pep_num_from_file "$pep")
                pep_id=$(get_pep_id "$((10#$num))")
                title=$(get_pep_field "$pep" "Title")
                status=$(get_pep_field "$pep" "Status")
                upd=$(get_pep_field "$pep" "Updated")
                echo "  - ${pep_id}: ${title} — ${status} (updated ${upd})"
            done
        fi
    fi
}

# Switch docs/templates/pep-template.md between the with-AI-block and
# without-AI-block variants (docs/templates/pep-template-ai.md and
# docs/templates/pep-template-no-ai.md), or report which one is active.
ai_block() {
    local action="${1:-status}"
    local active="${TEMPLATE_DIR}/pep-template.md"
    local ai_variant="${TEMPLATE_DIR}/pep-template-ai.md"
    local no_ai_variant="${TEMPLATE_DIR}/pep-template-no-ai.md"

    case "$action" in
        on|off) ;;
        status) ;;
        *)
            log "ERROR" "Unknown action: $action"
            log "INFO" "Usage: $0 ai-block <on|off|status>"
            exit 1
            ;;
    esac

    if [ "$action" = "status" ]; then
        if [ ! -f "$active" ]; then
            log "WARN" "No active template found: $active"
            return
        fi
        if [ -f "$ai_variant" ] && diff -q "$active" "$ai_variant" >/dev/null 2>&1; then
            log "INFO" "AI block: on ($active matches pep-template-ai.md)"
        elif [ -f "$no_ai_variant" ] && diff -q "$active" "$no_ai_variant" >/dev/null 2>&1; then
            log "INFO" "AI block: off ($active matches pep-template-no-ai.md)"
        else
            log "INFO" "AI block: unknown — $active has been customised and no longer matches either variant"
        fi
        return
    fi

    local source_variant="$no_ai_variant"
    local label="without"
    if [ "$action" = "on" ]; then
        source_variant="$ai_variant"
        label="with"
    fi

    if [ ! -f "$source_variant" ]; then
        log "ERROR" "Variant not found: $source_variant"
        log "INFO" "Run '$0 update-templates' to pull the latest template variants from source"
        exit 1
    fi

    cp "$source_variant" "$active"
    log "INFO" "Switched $active to the $label-AI-block variant"
    log "WARN" "This overwrote any manual edits to $active — the other variant file was left untouched"
}

# Strip the "## Claude Prompt Context" section out of existing PEP files.
# ai-block on/off only swaps the *template* used by new-pep — this cleans up
# PEPs that were already created while the AI-block template was active.
strip_ai_block() {
    local dry_run=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            *) log "ERROR" "Unknown option: $1"; log "INFO" "Usage: $0 strip-ai-block [--dry-run]"; exit 1 ;;
        esac
    done

    if [ ! -d "$PEP_DIR" ]; then
        log "WARN" "PEP directory does not exist: $PEP_DIR"
        return
    fi

    local stripped=0 skipped=0

    for pep in "$PEP_DIR"/pep-*.md; do
        [ -f "$pep" ] || continue

        if ! grep -q '^## Claude Prompt Context[[:space:]]*$' "$pep"; then
            skipped=$((skipped + 1))
            continue
        fi

        log "INFO" "$([ "$dry_run" = true ] && echo "Would strip" || echo "Stripping") AI block: $(basename "$pep")"
        stripped=$((stripped + 1))

        $dry_run && continue

        awk '
            /^## Claude Prompt Context[[:space:]]*$/ { skip=1; next }
            skip && /^## / { skip=0 }
            skip { next }
            { print }
        ' "$pep" > "${pep}.tmp" && mv "${pep}.tmp" "$pep"
    done

    if [ $((stripped + skipped)) -eq 0 ]; then
        log "INFO" "No PEP files found"
        return
    fi

    if $dry_run; then
        log "INFO" "Dry run: $stripped file(s) would be stripped, $skipped had no AI block"
    else
        log "INFO" "Done: $stripped file(s) stripped, $skipped had no AI block"
        if [ "$stripped" -gt 0 ] && [ -d ".git" ]; then
            log "INFO" "Review the changes then commit: git add -A && git commit -m 'chore: remove AI block from PEPs'"
        fi
    fi
}

# Install, remove, or report on Claude Code skills (.claude/skills/) — the
# runtime counterpart to the include_claude_skills cookiecutter option.
# update-templates only *syncs* skills into projects that already have them,
# specifically so a passive `update-templates` run can't silently turn the
# feature on. This command is the explicit opt-in/opt-out path — the only way
# to bootstrap skills into a project that predates this feature, or was
# generated with include_claude_skills=n and wants them later.
claude_skills() {
    local action="${1:-status}"
    shift || true

    case "$action" in
        on|off|status) ;;
        *)
            log "ERROR" "Unknown action: $action"
            log "INFO" "Usage: $0 claude-skills <on|off|status> [--source <path|git|url>]"
            exit 1
            ;;
    esac

    if [ "$action" = "status" ]; then
        if [ -d ".claude/skills" ]; then
            local names
            names=$(find .claude/skills -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | tr '\n' ' ')
            log "INFO" "Claude skills: installed (${names:-none found})"
        else
            log "INFO" "Claude skills: not installed. Run '$0 claude-skills on' to install."
        fi
        return
    fi

    if [ "$action" = "off" ]; then
        if [ -d ".claude/skills" ]; then
            rm -rf ".claude/skills"
            if [ -d ".claude" ] && [ -z "$(ls -A .claude)" ]; then
                rmdir ".claude"
            fi
            log "INFO" "Removed .claude/skills"
        else
            log "INFO" "Claude skills already not installed"
        fi
        return
    fi

    # action = on — resolve source the same way as update-tools/update-templates:
    # --source flag > PEP_FRAMEWORK_SOURCE > this framework's default git repo.
    local source=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --source) source="$2"; shift 2 ;;
            *) log "ERROR" "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$source" ] && [ -n "${PEP_FRAMEWORK_SOURCE:-}" ]; then
        source="$PEP_FRAMEWORK_SOURCE"
    fi
    if [ -z "$source" ]; then
        source="$DEFAULT_TEMPLATE_REPO"
        log "INFO" "No source specified — defaulting to $source"
    fi

    local project_root_src
    if is_git_source "$source"; then
        clone_git_source "$source"
        project_root_src="${_GIT_SRC_TMPDIR}/repo/{{cookiecutter.project_slug}}"
    elif echo "$source" | grep -qE '^https?://'; then
        local derived
        derived=$(derive_git_url_from_raw "$source")
        if [ -z "$derived" ]; then
            log "WARN" "This source is a single-file URL, not a git repo — claude-skills needs the whole repo."
            log "INFO" "Falling back to the default template repo: $DEFAULT_TEMPLATE_REPO"
            derived="$DEFAULT_TEMPLATE_REPO"
        else
            log "INFO" "Derived git repo from raw-file source: $derived"
        fi
        clone_git_source "$derived"
        project_root_src="${_GIT_SRC_TMPDIR}/repo/{{cookiecutter.project_slug}}"
    else
        local src_dir="$source"
        [ -f "$source" ] && src_dir="$(dirname "$source")"
        project_root_src="$(cd "${src_dir}/.." 2>/dev/null && pwd)" || true
    fi

    local skills_src="${project_root_src:+${project_root_src}/.claude/skills}"
    if [ -z "$skills_src" ] || [ ! -d "$skills_src" ]; then
        log "ERROR" "Claude skills not found in source. Expected at: ${skills_src:-<unresolved from $source>}"
        exit 1
    fi

    mkdir -p ".claude/skills"
    local installed=0
    for skill_dir in "$skills_src"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill_name
        skill_name="$(basename "$skill_dir")"
        mkdir -p ".claude/skills/${skill_name}"
        cp "${skill_dir}"*.md ".claude/skills/${skill_name}/" 2>/dev/null
        installed=$((installed + 1))
    done

    log "INFO" "Installed ${installed} Claude skill(s) from ${skills_src}"
    log "INFO" "Future 'update-templates' runs will now keep these in sync automatically"
}

# Show Draft/Active PEPs grouped by priority — a work queue for deciding
# what to pick up next. Ignores terminal statuses (Implemented/Rejected/
# Superseded) entirely.
show_next() {
    if [ ! -d "$PEP_DIR" ]; then
        log "WARN" "PEP directory does not exist: $PEP_DIR"
        return
    fi

    echo -e "${BLUE}What to work on next (Draft/Active, by priority):${NC}"
    echo "===================================================="

    local priorities=("High" "Medium" "Low")
    local any_found=false

    for priority in "${priorities[@]}"; do
        local files=()
        for pep in "$PEP_DIR"/pep-*.md; do
            [ -f "$pep" ] || continue
            local status
            status=$(get_pep_field "$pep" "Status")
            [ "$status" = "Draft" ] || [ "$status" = "Active" ] || continue
            local pep_priority
            pep_priority=$(get_pep_field "$pep" "Priority")
            [ "$pep_priority" = "$priority" ] || continue
            files+=("$pep")
        done

        [ ${#files[@]} -eq 0 ] && continue
        any_found=true

        echo ""
        echo "## $priority (${#files[@]})"
        for pep in "${files[@]}"; do
            local num pep_id title status pep_type abstract
            num=$(get_pep_num_from_file "$pep")
            pep_id=$(get_pep_id "$((10#$num))")
            title=$(get_pep_field "$pep" "Title")
            status=$(get_pep_field "$pep" "Status")
            pep_type=$(get_pep_field "$pep" "Type")
            abstract=$(get_pep_abstract "$pep")
            echo "- ${pep_id} [${pep_type}] ${title} (${status})"
            [ -n "$abstract" ] && echo "    ${abstract}"
        done
    done

    if [ "$any_found" = false ]; then
        echo ""
        echo "Nothing in Draft or Active — nothing queued to work on."
    fi
}

# List PEPs whose content is still mostly template boilerplate — i.e. not yet
# fleshed out. Compares each PEP's body (everything from the first "## "
# heading onward, so the auto-filled header table doesn't count) against the
# active template using a line diff; PEPs at or above --threshold percent
# unchanged are flagged as stubs.
show_stubs() {
    local threshold=85

    while [ $# -gt 0 ]; do
        case "$1" in
            --threshold) threshold="$2"; shift 2 ;;
            *) log "ERROR" "Unknown option: $1"; log "INFO" "Usage: $0 stubs [--threshold N]"; exit 1 ;;
        esac
    done

    if [ ! -d "$PEP_DIR" ]; then
        log "WARN" "PEP directory does not exist: $PEP_DIR"
        return
    fi

    local template="${TEMPLATE_DIR}/pep-template.md"
    if [ ! -f "$template" ]; then
        log "ERROR" "PEP template not found: $template"
        exit 1
    fi

    echo -e "${BLUE}PEPs still mostly template boilerplate (>= ${threshold}% unchanged):${NC}"
    echo "======================================================================"

    local template_body
    template_body=$(awk '/^## /{body=1} body{print}' "$template")
    local template_lines
    template_lines=$(printf '%s\n' "$template_body" | wc -l | tr -d ' ')

    local found=false
    for pep in "$PEP_DIR"/pep-*.md; do
        [ -f "$pep" ] || continue

        local file_body
        file_body=$(awk '/^## /{body=1} body{print}' "$pep")

        # diff exits 1 when the inputs differ and grep -c exits 1 when it finds
        # no matches (i.e. identical files) — guard both against `set -e`.
        local diff_lines
        diff_lines=$( { diff <(printf '%s\n' "$template_body") <(printf '%s\n' "$file_body") || true; } | grep -c '^[<>]' || true)
        local changed_pairs=$(( (diff_lines + 1) / 2 ))

        local percent_unchanged=100
        if [ "$template_lines" -gt 0 ]; then
            percent_unchanged=$(( 100 - (changed_pairs * 100 / template_lines) ))
            [ "$percent_unchanged" -lt 0 ] && percent_unchanged=0
        fi

        if [ "$percent_unchanged" -ge "$threshold" ]; then
            found=true
            local num pep_id title status
            num=$(get_pep_num_from_file "$pep")
            pep_id=$(get_pep_id "$((10#$num))")
            title=$(get_pep_field "$pep" "Title")
            status=$(get_pep_field "$pep" "Status")
            printf "%-20s %3d%% unchanged   %-40s (%s)\n" "$pep_id" "$percent_unchanged" "$title" "$status"
        fi
    done

    if [ "$found" = false ]; then
        echo "None — every PEP has been fleshed out beyond the template."
    fi
}

# Initialize PEP framework in current directory
init_framework() {
    log "INFO" "Initializing PEP framework..."

    ensure_directories
    cleanup_blog_artifacts

    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
# PEP Framework Configuration — project-level settings (commit this file)
PROJECT_NAME="$(basename "$(pwd)")"

# PEP identifier codes — combined to build IDs like PEP-PROJECT_CODE-REPO_CODE-001
# Leave blank to fall back to the default PEP-001 format
PROJECT_CODE=""
REPO_CODE=""

# Enable/disable the Blogs (Build Logs) feature
ENABLE_BLOGS="y"

# Integration settings
ZABBIX_HOST=""
GRAFANA_URL=""

# Notification settings (optional)
SLACK_WEBHOOK=""
EMAIL_NOTIFICATIONS="false"

# Git integration — require all commits to reference a PEP
REQUIRE_PEP_REFERENCE=false

# Debug mode
DEBUG="false"
EOF
        log "INFO" "Created configuration file: $CONFIG_FILE"
    fi

    local local_config="${CONFIG_FILE}.local"
    if [ ! -f "$local_config" ]; then
        cat > "$local_config" << EOF
# PEP Framework — personal settings (do NOT commit this file)
PEP_AUTHOR="$(git config user.name 2>/dev/null || echo 'Your Name')"
DEFAULT_EDITOR="${EDITOR:-vi}"
AUTO_OPEN_EDITOR="true"
EOF
        log "INFO" "Created personal configuration: $local_config"
    fi

    create_templates
    setup_git_hooks

    log "INFO" "PEP framework initialized successfully!"
    log "INFO" "Edit $CONFIG_FILE to set your PROJECT_CODE and REPO_CODE"
    log "INFO" "Create your first PEP with: $0 new-pep 'Project Foundation'"
}

# Warn if templates are missing (they come from cookiecutter or update-templates)
create_templates() {
    if [ ! -f "${TEMPLATE_DIR}/pep-template.md" ]; then
        log "WARN" "PEP template not found: ${TEMPLATE_DIR}/pep-template.md"
        log "INFO" "Run '$0 update-templates --source <path>' to pull templates from source"
    fi

    if [ "${ENABLE_BLOGS:-y}" = "y" ] && [ ! -f "${TEMPLATE_DIR}/blog-template.md" ]; then
        log "WARN" "BLOG template not found: ${TEMPLATE_DIR}/blog-template.md"
        log "INFO" "Run '$0 update-templates --source <path>' to pull templates from source"
    fi
}

# True if $1 looks like a cloneable git remote (repo URL) rather than a
# single raw-file URL — i.e. it ends in .git, or is an SSH-style git remote.
is_git_source() {
    case "$1" in
        *.git|git@*|ssh://*) return 0 ;;
        *) return 1 ;;
    esac
}

# Best-effort: turn a raw-file GitHub URL into its repo's git clone URL, so a
# PEP_FRAMEWORK_SOURCE saved as a single-file URL (e.g. by an older
# update-tools, which only ever needed to fetch pep-tools.sh) still works for
# update-templates, which needs the whole repo. Echoes nothing if it can't
# recognize the URL shape — pure function, safe to call via $(...).
derive_git_url_from_raw() {
    local url="$1"
    if [[ "$url" =~ ^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/ ]]; then
        echo "https://github.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}.git"
    elif [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/(blob|raw)/ ]]; then
        echo "https://github.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}.git"
    fi
}

_GIT_SRC_TMPDIR=""
_cleanup_git_source() {
    [ -n "$_GIT_SRC_TMPDIR" ] && rm -rf "$_GIT_SRC_TMPDIR"
}

# Shallow-clones a git source into $_GIT_SRC_TMPDIR/repo and registers cleanup
# on script exit. Sets the global $_GIT_SRC_TMPDIR rather than returning the
# path via command substitution — a `trap ... EXIT` set inside a $(...)
# subshell fires when that subshell exits, not the main script, which would
# delete the clone before the caller ever reads it. Call this directly.
clone_git_source() {
    local url="$1"

    if ! command -v git >/dev/null 2>&1; then
        log "ERROR" "git is required to fetch from a git source: $url"
        exit 1
    fi

    _GIT_SRC_TMPDIR=$(mktemp -d)
    trap _cleanup_git_source EXIT

    log "INFO" "Cloning $url ..."
    if ! git clone --depth 1 --quiet "$url" "${_GIT_SRC_TMPDIR}/repo" >/dev/null 2>&1; then
        log "ERROR" "Failed to clone: $url"
        exit 1
    fi

    if [ ! -d "${_GIT_SRC_TMPDIR}/repo/{{cookiecutter.project_slug}}" ]; then
        log "ERROR" "Expected {{cookiecutter.project_slug}}/ not found in clone: $url"
        exit 1
    fi
}

# Update pep-tools.sh from a source path, git URL, or raw-file URL
update_tools() {
    local source=""
    local save_source=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --source) source="$2"; shift 2 ;;
            --save)   save_source=true; shift ;;
            *) log "ERROR" "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$source" ] && [ -n "${PEP_FRAMEWORK_SOURCE:-}" ]; then
        source="$PEP_FRAMEWORK_SOURCE"
    fi

    if [ -z "$source" ]; then
        source="$DEFAULT_TEMPLATE_REPO"
        log "INFO" "No source specified — defaulting to $source"
    fi

    local dest="tools/pep-tools.sh"
    local backup="${dest}.bak"

    cp "$dest" "$backup"
    log "INFO" "Backed up current tools to $backup"

    if is_git_source "$source"; then
        clone_git_source "$source"
        local src_file="${_GIT_SRC_TMPDIR}/repo/{{cookiecutter.project_slug}}/tools/pep-tools.sh"
        if [ ! -f "$src_file" ]; then
            log "ERROR" "Source file not found: $src_file"
            cp "$backup" "$dest"; exit 1
        fi
        cp "$src_file" "$dest"
        sync_hook_from_dir "${_GIT_SRC_TMPDIR}/repo/{{cookiecutter.project_slug}}/tools" || true
    elif echo "$source" | grep -qE '^https?://'; then
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$source" -o "$dest"
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$dest" "$source"
        else
            log "ERROR" "Neither curl nor wget found"
            cp "$backup" "$dest"; exit 1
        fi
        log "WARN" "Raw-file source: the commit-msg hook was NOT refreshed — run '$0 update-hooks' too"
    else
        local src_file="$source"
        [ -d "$source" ] && src_file="$source/pep-tools.sh"
        if [ ! -f "$src_file" ]; then
            log "ERROR" "Source file not found: $src_file"
            cp "$backup" "$dest"; exit 1
        fi
        cp "$src_file" "$dest"
        sync_hook_from_dir "$(dirname "$src_file")" || true
    fi

    chmod +x "$dest"
    log "INFO" "Updated $dest from $source"

    local local_config="${CONFIG_FILE}.local"
    if $save_source || [ -z "${PEP_FRAMEWORK_SOURCE:-}" ]; then
        if grep -q "PEP_FRAMEWORK_SOURCE" "$local_config" 2>/dev/null; then
            sed -i.bak "s|PEP_FRAMEWORK_SOURCE=.*|PEP_FRAMEWORK_SOURCE=\"$source\"|" "$local_config"
            rm -f "${local_config}.bak"
        else
            echo "PEP_FRAMEWORK_SOURCE=\"$source\"" >> "$local_config"
        fi
        log "INFO" "Saved PEP_FRAMEWORK_SOURCE to $local_config"
    fi

    # Exit immediately — bash reads scripts in chunks from disk; continuing after
    # replacing this file causes it to read garbage at the old byte offset.
    exit 0
}

# Update template files from a source path
update_templates() {
    local source=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --source) source="$2"; shift 2 ;;
            *) log "ERROR" "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$source" ] && [ -n "${PEP_FRAMEWORK_SOURCE:-}" ]; then
        source="$PEP_FRAMEWORK_SOURCE"
    fi

    if [ -z "$source" ]; then
        source="$DEFAULT_TEMPLATE_REPO"
        log "INFO" "No source specified — defaulting to $source"
    fi

    local project_root_src
    if is_git_source "$source"; then
        clone_git_source "$source"
        project_root_src="${_GIT_SRC_TMPDIR}/repo/{{cookiecutter.project_slug}}"
    elif echo "$source" | grep -qE '^https?://'; then
        # A raw single-file URL (e.g. saved by an older update-tools, which
        # only ever needed pep-tools.sh) can't be used directly — try to
        # derive its repo's clone URL, or fall back to the default repo.
        local derived
        derived=$(derive_git_url_from_raw "$source")
        if [ -z "$derived" ]; then
            log "WARN" "This source is a single-file URL, not a git repo — update-templates needs the whole repo."
            log "INFO" "Falling back to the default template repo: $DEFAULT_TEMPLATE_REPO"
            derived="$DEFAULT_TEMPLATE_REPO"
        else
            log "INFO" "Derived git repo from raw-file source: $derived"
        fi
        clone_git_source "$derived"
        project_root_src="${_GIT_SRC_TMPDIR}/repo/{{cookiecutter.project_slug}}"
    else
        local src_dir="$source"
        [ -f "$source" ] && src_dir="$(dirname "$source")"
        project_root_src="$(cd "${src_dir}/.." 2>/dev/null && pwd)" || true
    fi

    local template_src="${project_root_src:+${project_root_src}/docs/templates}"

    if [ -z "$template_src" ] || [ ! -d "$template_src" ]; then
        log "ERROR" "Templates directory not found. Expected at: ${template_src:-<unresolved from $source>}"
        exit 1
    fi

    ensure_directories

    local updated=0
    for template in pep-template.md pep-template-ai.md pep-template-no-ai.md blog-template.md; do
        if [ -f "${template_src}/${template}" ]; then
            cp "${template_src}/${template}" "${TEMPLATE_DIR}/${template}"
            log "INFO" "Updated ${TEMPLATE_DIR}/${template}"
            updated=$((updated + 1))
        else
            log "WARN" "Not found in source: ${template_src}/${template}"
        fi
    done

    log "INFO" "Updated ${updated} template(s) from ${template_src}"

    # Sync Claude Code skills too, but only if this project already opted in
    # (.claude/skills exists locally) — update-templates shouldn't turn the
    # feature on for projects that were generated with it off.
    if [ -d ".claude/skills" ]; then
        local skills_src="${project_root_src}/.claude/skills"
        if [ -d "$skills_src" ]; then
            local skills_updated=0
            for skill_dir in "$skills_src"/*/; do
                [ -d "$skill_dir" ] || continue
                local skill_name
                skill_name="$(basename "$skill_dir")"
                mkdir -p ".claude/skills/${skill_name}"
                cp "${skill_dir}"*.md ".claude/skills/${skill_name}/" 2>/dev/null
                skills_updated=$((skills_updated + 1))
            done
            log "INFO" "Updated ${skills_updated} Claude skill(s) from ${skills_src}"
        else
            log "WARN" "Claude skills not found in source: ${skills_src}"
        fi
    fi
}

# Setup git hooks — copy tools/git-hooks/commit-msg into the repo's hooks dir.
# Uses git's own path lookup so worktrees and core.hooksPath are honoured.
setup_git_hooks() {
    local source_hook="tools/git-hooks/commit-msg"
    local hook_file

    if [ ! -f "$source_hook" ]; then
        log "WARN" "Git hook source not found: $source_hook"
        return
    fi

    if hook_file=$(git rev-parse --git-path hooks/commit-msg 2>/dev/null); then
        mkdir -p "$(dirname "$hook_file")"
        cp "$source_hook" "$hook_file"
        chmod +x "$hook_file"
        log "INFO" "Installed git commit-msg hook: $hook_file"
    else
        log "WARN" "Not in a git repository, skipping hook installation"
    fi
}

# Refresh tools/git-hooks/commit-msg from a framework tools directory (the one
# holding pep-tools.sh and git-hooks/), then reinstall it into the repo's hooks
# dir. $1 = tools dir.
sync_hook_from_dir() {
    local tools_dir="$1"
    local src_hook="${tools_dir}/git-hooks/commit-msg"
    local dest_hook="tools/git-hooks/commit-msg"

    if [ ! -f "$src_hook" ]; then
        log "WARN" "Git hook not found in source: $src_hook"
        return 1
    fi

    mkdir -p "$(dirname "$dest_hook")"
    if [ -f "$dest_hook" ] && cmp -s "$src_hook" "$dest_hook"; then
        log "INFO" "Hook source already current: $dest_hook"
    else
        cp "$src_hook" "$dest_hook"
        log "INFO" "Updated $dest_hook"
    fi
    chmod +x "$dest_hook"
    setup_git_hooks
}

# Resolve the update source (flag, PEP_FRAMEWORK_SOURCE, or default repo) and
# refresh the hook from it. Used by `update-hooks`; update-tools reuses
# sync_hook_from_dir directly because it has already fetched the source.
update_hooks() {
    local source=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --source) source="$2"; shift 2 ;;
            *) log "ERROR" "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$source" ] && [ -n "${PEP_FRAMEWORK_SOURCE:-}" ]; then
        source="$PEP_FRAMEWORK_SOURCE"
    fi
    if [ -z "$source" ]; then
        source="$DEFAULT_TEMPLATE_REPO"
        log "INFO" "No source specified — defaulting to $source"
    fi

    if is_git_source "$source"; then
        clone_git_source "$source"
        sync_hook_from_dir "${_GIT_SRC_TMPDIR}/repo/{{cookiecutter.project_slug}}/tools" || exit 1
    elif echo "$source" | grep -qE '^https?://'; then
        local derived
        derived=$(derive_git_url_from_raw "$source")
        [ -n "$derived" ] || derived="$DEFAULT_TEMPLATE_REPO"
        clone_git_source "$derived"
        sync_hook_from_dir "${_GIT_SRC_TMPDIR}/repo/{{cookiecutter.project_slug}}/tools" || exit 1
    else
        local src_dir="$source"
        [ -f "$source" ] && src_dir="$(dirname "$source")"
        sync_hook_from_dir "$src_dir" || exit 1
    fi
}

# Show help
show_help() {
    local file_prefix
    file_prefix=$(get_file_prefix)
    local example_id
    example_id=$(get_pep_id 1)
    local id_format="${example_id%001}NNN"

    cat << EOF
${BLUE}PEP Management Tool v2.0${NC}
========================

${GREEN}Usage:${NC} $0 <command> [arguments]

${GREEN}PEP commands:${NC}
  ${YELLOW}new-pep${NC} [flags] [number] [title]        Create a new PEP (prompts for type, priority, abstract)
                                               Flags skip prompts: --type T, --priority P, --abstract TEXT
                                               --no-open never launches an editor. The number defaults to
                                               one more than the highest on any local/remote branch
  ${YELLOW}new-branch${NC} [--here] [pep-num]          Create git feature branch for a PEP. --here, or
                                               BRANCH_PER_PEP=false in .peprc, stays on the current branch
  ${YELLOW}commit${NC} <pep-num> [message]              Commit with correct PEP message format
$([ "${ENABLE_BLOGS:-y}" = "y" ] && echo "  ${YELLOW}new-blog${NC} [blog-num] [pep-num]         Create implementation blog for a PEP")
  ${YELLOW}list${NC}                                    List all PEPs with status
  ${YELLOW}status${NC} [--since YYYY-MM-DD] [--show-all]  Status summary (with an Open/Closed rollup), by-status
                                               listing (copy/paste-ready), flags PEPs with an unexpected/
                                               missing status, and with --since adds a Changes section:
                                               new PEPs raised (grouped by current status), pre-existing
                                               PEPs closed, and other updates. Implemented/Rejected/
                                               Superseded PEPs closed more than 60 days ago are collapsed
                                               to a summary line in the by-status listing — pass
                                               --show-all to list every PEP in full
  ${YELLOW}next${NC}                                    Draft/Active PEPs grouped by priority — what to work on next
  ${YELLOW}stubs${NC} [--threshold N]                   List PEPs still mostly template boilerplate (default 85%)
  ${YELLOW}migrate${NC} [--dry-run]                     Rename existing PEPs to current naming scheme
  ${YELLOW}fix-naming${NC} [--dry-run]                  Repair PEPs written with the old CODES-PEP-NNN ID order

${GREEN}Framework commands:${NC}
  ${YELLOW}init${NC}                                    Initialize PEP framework in current directory
  ${YELLOW}ai-block${NC} <on|off|status>                Switch docs/templates/pep-template.md between the
                                               with-AI-block and without-AI-block variants
  ${YELLOW}strip-ai-block${NC} [--dry-run]              Remove the Claude Prompt Context section from existing
                                               PEPs (use after switching the template with 'ai-block off')
  ${YELLOW}claude-skills${NC} <on|off|status>           Install/remove/report Claude Code skills (.claude/skills/)
                                               — the only way to bootstrap skills into a project that
                                               predates this feature or was generated with it off
  ${YELLOW}update-tools${NC} [--source <path|git|url>]  Update pep-tools.sh from source (defaults to the
                                               framework's git repo if none is configured)
  ${YELLOW}update-templates${NC} [--source <path|git>]  Update PEP/BLOG templates from source (same default)
  ${YELLOW}update-hooks${NC} [--source <path|git>]      Refresh tools/git-hooks/commit-msg from source AND
                                               reinstall it into .git/hooks (update-tools does this too)
  ${YELLOW}help${NC}                                    Show this help message

${GREEN}Examples:${NC}
  $0 new-pep "Monitoring Integration"        # create PEP, answer type/priority/abstract prompts
  $0 new-branch 5                            # create feature/pep-...-005-... branch
  $0 commit 5 "Add Prometheus scrape config" # commit with correct prefix
$([ "${ENABLE_BLOGS:-y}" = "y" ] && echo "  $0 new-blog 3 5                           # create blog-003 for pep-005")
  $0 status --since 2026-07-01                # meeting prep: summary + by-status list + changes since date
  $0 status --show-all                       # by-status list with no old-closed-PEPs collapsing
  $0 next                                    # what to pick up next, by priority
  $0 stubs                                   # PEPs that still need fleshing out
  $0 migrate --dry-run                       # preview rename of old-format PEPs
  $0 migrate                                 # apply rename
  $0 fix-naming --dry-run                    # preview repair of PS-SLT-PEP-NNN style IDs
  $0 fix-naming                              # apply repair
  $0 ai-block on                             # switch to the with-AI-block PEP template
  $0 strip-ai-block --dry-run                # preview removing the AI block from existing PEPs
  $0 strip-ai-block                          # apply
  $0 claude-skills on                        # install Claude Code skills into an existing project
  $0 claude-skills status                    # check whether skills are installed
  $0 claude-skills off                       # remove them
  $0 update-tools                            # no source configured — clones the framework's git repo
  $0 update-tools --source /path/to/cookiecutter/\{\{cookiecutter.project_slug\}\}/tools
  $0 update-templates                        # uses PEP_FRAMEWORK_SOURCE, or the git repo if unset

${GREEN}PEP Types:${NC}
  Project | Feature | Process | Infrastructure | Documentation | Bug | Enhancement | Research | Security | Performance

${GREEN}ID & file naming (this repo):${NC}
  ID format:   ${YELLOW}${id_format}${NC}   (e.g. ${example_id})
  File format: ${YELLOW}${file_prefix}NNN-type-slug.md${NC}
  Commit:      ${YELLOW}$(echo "$file_prefix" | tr '[:upper:]' '[:lower:]')NNN: description${NC}
  Branch:      ${YELLOW}feature/${file_prefix}NNN-type-slug${NC}

${GREEN}Configuration:${NC}
  ${YELLOW}.peprc${NC}       — project settings: PROJECT_CODE, REPO_CODE, ENABLE_BLOGS (commit this)
  ${YELLOW}.peprc.local${NC} — personal settings: PEP_AUTHOR, DEFAULT_EDITOR, PEP_FRAMEWORK_SOURCE (gitignored)
EOF
}

# Main script logic
main() {
    case "${1:-help}" in
        "init")
            init_framework
            ;;
        "ai-block")
            shift
            ai_block "$@"
            ;;
        "strip-ai-block")
            shift
            strip_ai_block "$@"
            ;;
        "claude-skills")
            shift
            claude_skills "$@"
            ;;
        "new-pep")
            shift
            create_pep "$@"
            ;;
        "new-branch")
            shift
            new_branch "$@"
            ;;
        "commit")
            shift
            commit_pep "$@"
            ;;
        "new-blog")
            create_blog "$2" "$3"
            ;;
        "list")
            list_peps
            ;;
        "status")
            shift
            show_status "$@"
            ;;
        "next")
            show_next
            ;;
        "stubs")
            shift
            show_stubs "$@"
            ;;
        "migrate")
            shift
            migrate_peps "$@"
            ;;
        "fix-naming")
            shift
            fix_naming "$@"
            ;;
        "update-tools")
            shift
            update_tools "$@"
            ;;
        "update-templates")
            shift
            update_templates "$@"
            ;;
        "update-hooks")
            shift
            update_hooks "$@"
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

main "$@"
