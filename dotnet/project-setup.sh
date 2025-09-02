#!/usr/bin/env bash

# A script to scaffold a new .NET solution with a standard src/tests structure.
#
# set -e: Exit immediately if a command exits with a non-zero status.
# set -u: Treat unset variables as an error when substituting.
# set -o pipefail: The return value of a pipeline is the status of the last command
#                  to exit with a non-zero status.
set -euo pipefail

# --- Configuration & Colors ---
readonly SCRIPT_NAME=$(basename "$0")
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_NC='\033[0m'

# --- Helper Functions ---
info() {
    echo -e "${COLOR_GREEN}INFO: $1${COLOR_NC}"
}

error() {
    echo -e "${COLOR_RED}ERROR: $1${COLOR_NC}" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <ProjectName> <ProjectType>

Scaffolds a new .NET solution with a standard src/tests structure.

Arguments:
  <ProjectName>       The name for the solution and the main project.
  <ProjectType>       The .NET template for the main project (e.g., 'console', 'webapi', 'classlib').

Options:
  -l, --lang <LANG>   The project language. Can be 'F#' or 'C#'. (Default: F#)
  -h, --help          Display this help message.

Example:
  # Create an F# console application
  $SCRIPT_NAME FSharpConsoleApp console

  # Create a C# Web API project
  $SCRIPT_NAME MyAwesomeApi webapi -l "C#"
EOF
    exit 1
}

# --- Main Logic ---
main() {
    # --- Parameter Parsing ---
    local LANGUAGE="F#" # Default language

    # Parse options first
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--lang)
                LANGUAGE="$2"
                shift 2 # past argument and value
                ;;
            -h|--help)
                usage
                ;;
            -*)
                # Stop parsing options if we hit something unknown that doesn't start with -
                # This allows project names to potentially start with a dash if needed, although unlikely.
                if [[ "$1" == "--" ]]; then shift; fi
                break
                ;;
            *)
                # Positional arguments start here
                break
                ;;
        esac
    done

    if [[ $# -ne 2 ]]; then
        error "Invalid number of arguments. ProjectName and ProjectType are required."
    fi

    local SOLUTION_NAME="$1"
    local PROJECT_TYPE="$2"

    # --- Prerequisite Check ---
    if ! command -v dotnet &> /dev/null; then
        error "'dotnet' command not found. Please install the .NET SDK."
    fi

    if [[ -d "$SOLUTION_NAME" ]]; then
        error "Directory '$SOLUTION_NAME' already exists. Aborting."
    fi

    # --- Determine Project File Extension ---
    local PROJ_EXT
    case ${LANGUAGE,,} in # convert to lowercase
        f#|fsharp)
            LANGUAGE="F#"
            PROJ_EXT="fsproj"
            ;;
        c#|csharp)
            LANGUAGE="C#"
            PROJ_EXT="csproj"
            ;;
        *)
            error "Unsupported language: '$LANGUAGE'. Please use 'F#' or 'C#'."
            ;;
    esac

    # --- Variable Definitions ---
    local MAIN_PROJECT_DIR="src/$SOLUTION_NAME"
    local TEST_PROJECT_DIR="tests/$SOLUTION_NAME.Tests"
    local MAIN_PROJECT_FILE="$MAIN_PROJECT_DIR/$SOLUTION_NAME.$PROJ_EXT"
    local TEST_PROJECT_FILE="$TEST_PROJECT_DIR/$SOLUTION_NAME.Tests.$PROJ_EXT"

    info "--- Starting setup for '$SOLUTION_NAME' ($LANGUAGE) ---"

    # --- Scaffolding Commands ---
    set -x # Echo all commands being executed

    # :info "Step 1: Creating directory structure..."
    # This should be made ahead of time and loaded with proper flake
    # mkdir -p "$SOLUTION_NAME"
    # cd "$SOLUTION_NAME"
    mkdir src tests

    info "Step 2: Creating solution file..."
    dotnet new sln -n "$SOLUTION_NAME"

    info "Step 3: Creating main project ($PROJECT_TYPE)..."
    dotnet new "$PROJECT_TYPE" -lang "$LANGUAGE" -o "$MAIN_PROJECT_DIR" -n "$SOLUTION_NAME"

    info "Step 4: Creating test project (xunit)..."
    dotnet new expecto -o "$TEST_PROJECT_DIR" -n "$SOLUTION_NAME.Tests"

    info "Step 5: Adding projects to solution..."
    dotnet sln add "$MAIN_PROJECT_FILE"
    dotnet sln add "$TEST_PROJECT_FILE"

    info "Step 6: Adding project reference from Tests to Main..."
    dotnet add "$TEST_PROJECT_FILE" reference "$MAIN_PROJECT_FILE"

    info "Step 7: Initializing Git repository..."
    git init
    dotnet new gitignore

    info "Step 8: Creating initial commit..."
    git add .

    set +x # Stop echoing commands

    echo
    info "--- Setup Complete! ---"
    echo "Next steps:"
    echo "  1. Update '.git/config' to use git:git-personal or git:git-work"
    echo "  2. gh repo create"
}

main "$@"
