#!/bin/bash
# Enhanced Claude Code statusline with advanced features
# Enhanced: 2025-01-27 with git status, session tracking, language detection, and more
# Features: directory, enhanced-git, model, color-context, usage, session-duration, language-detection, project-name, weekly-usage
STATUSLINE_VERSION="3.2.0"
STATUSLINE_REPO="bulgariamitko/claude-code-statusline"
STATUSLINE_RAW_URL="https://raw.githubusercontent.com/${STATUSLINE_REPO}/main/statusline.sh"

# Cache directory for performance
CACHE_DIR="$HOME/.claude/.statusline_cache"
mkdir -p "$CACHE_DIR"
CACHE_TTL=30  # seconds for general cache

# ---- auto-update check (runs in background, once per day) ----
check_for_update() {
  local update_cache="$CACHE_DIR/update_check"
  local update_ttl=86400  # 24 hours

  # Skip if checked recently
  if [ -f "$update_cache" ] && [ $(($(date +%s) - $(stat -f%m "$update_cache" 2>/dev/null || stat -c%Y "$update_cache" 2>/dev/null || echo 0))) -lt $update_ttl ]; then
    return
  fi

  # Run update check in background to not block the statusline
  (
    remote_version=$(curl -sf --max-time 5 "$STATUSLINE_RAW_URL" 2>/dev/null | grep '^STATUSLINE_VERSION=' | head -1 | sed 's/STATUSLINE_VERSION="\(.*\)"/\1/')
    if [ -n "$remote_version" ] && [ "$remote_version" != "$STATUSLINE_VERSION" ]; then
      echo "$remote_version" > "$CACHE_DIR/update_available"
    else
      rm -f "$CACHE_DIR/update_available"
    fi
    date +%s > "$update_cache"
  ) &>/dev/null &
}

check_for_update

input=$(cat)

# Check if jq is available
HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
  HAS_JQ=1
fi

# ---- color helpers (force colors for Claude Code) ----
use_color=1
[ -n "$NO_COLOR" ] && use_color=0

C() { if [ "$use_color" -eq 1 ]; then printf '\033[%sm' "$1"; fi; }
RST() { if [ "$use_color" -eq 1 ]; then printf '\033[0m'; fi; }

# ---- modern sleek colors ----
dir_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;117m'; fi; }    # sky blue
model_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;147m'; fi; }  # light purple  
version_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;180m'; fi; } # soft yellow
cc_version_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;249m'; fi; } # light gray
style_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;245m'; fi; } # gray
project_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;153m'; fi; } # light blue
lang_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;213m'; fi; }   # pink
session_dur_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;186m'; fi; } # light yellow
todo_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;178m'; fi; }   # orange
rst() { if [ "$use_color" -eq 1 ]; then printf '\033[0m'; fi; }

# ---- caching utilities ----
is_cache_valid() {
  local cache_file="$1"
  [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null || echo 0))) -lt $CACHE_TTL ]
}

read_cache() {
  local cache_file="$1"
  [ -f "$cache_file" ] && cat "$cache_file"
}

write_cache() {
  local cache_file="$1"
  local content="$2"
  echo "$content" > "$cache_file"
}

# Check cache validity with custom TTL
is_cache_valid_ttl() {
  local cache_file="$1"
  local ttl="$2"
  [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null || echo 0))) -lt $ttl ]
}

# ---- usage tracking (from real-time statusline JSON) ----
# Claude Code provides rate_limits.five_hour and rate_limits.seven_day in the input JSON
get_session_usage() {
  local pct=""
  if [ "$HAS_JQ" -eq 1 ]; then
    pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
  else
    pct=$(echo "$input" | grep -o '"five_hour"[^}]*"used_percentage"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*$')
  fi
  if [ -n "$pct" ]; then
    printf '%.0f' "$pct"
  fi
}

get_weekly_usage() {
  local pct=""
  if [ "$HAS_JQ" -eq 1 ]; then
    pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
  else
    pct=$(echo "$input" | grep -o '"seven_day"[^}]*"used_percentage"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*$')
  fi
  if [ -n "$pct" ]; then
    printf '%.0f' "$pct"
  fi
}

get_session_reset_time() {
  local reset_epoch=""
  if [ "$HAS_JQ" -eq 1 ]; then
    reset_epoch=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
  else
    reset_epoch=$(echo "$input" | grep -o '"five_hour"[^}]*"resets_at"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$')
  fi
  if [ -n "$reset_epoch" ]; then
    local now=$(date +%s)
    local remaining=$((reset_epoch - now))
    if [ "$remaining" -gt 0 ]; then
      local days=$((remaining / 86400))
      local hours=$(((remaining % 86400) / 3600))
      local mins=$(((remaining % 3600) / 60))
      if [ "$days" -gt 0 ]; then
        echo "${days}d ${hours}h ${mins}m"
      else
        echo "${hours}h ${mins}m"
      fi
    else
      echo "expired"
    fi
  fi
}

get_weekly_reset_time() {
  local reset_epoch=""
  if [ "$HAS_JQ" -eq 1 ]; then
    reset_epoch=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)
  else
    reset_epoch=$(echo "$input" | grep -o '"seven_day"[^}]*"resets_at"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$')
  fi
  if [ -n "$reset_epoch" ]; then
    local now=$(date +%s)
    local remaining=$((reset_epoch - now))
    if [ "$remaining" -gt 0 ]; then
      local days=$((remaining / 86400))
      local hours=$(((remaining % 86400) / 3600))
      local mins=$(((remaining % 3600) / 60))
      if [ "$days" -gt 0 ]; then
        echo "${days}d ${hours}h ${mins}m"
      else
        echo "${hours}h ${mins}m"
      fi
    else
      echo "expired"
    fi
  fi
}

# ---- time helpers ----
to_epoch() {
  ts="$1"
  if command -v gdate >/dev/null 2>&1; then gdate -d "$ts" +%s 2>/dev/null && return; fi
  date -u -j -f "%Y-%m-%dT%H:%M:%S%z" "${ts/Z/+0000}" +%s 2>/dev/null && return
  python3 - "$ts" <<'PY' 2>/dev/null
import sys, datetime
s=sys.argv[1].replace('Z','+00:00')
print(int(datetime.datetime.fromisoformat(s).timestamp()))
PY
}

fmt_time_hm() {
  epoch="$1"
  if date -r 0 +%s >/dev/null 2>&1; then date -r "$epoch" +"%H:%M"; else date -d "@$epoch" +"%H:%M"; fi
}

progress_bar() {
  pct="${1:-0}"; width="${2:-10}"
  [[ "$pct" =~ ^[0-9]+$ ]] || pct=0; ((pct<0))&&pct=0; ((pct>100))&&pct=100
  filled=$(( pct * width / 100 )); empty=$(( width - filled ))
  printf '%*s' "$filled" '' | tr ' ' '='
  printf '%*s' "$empty" '' | tr ' ' '-'
}

# git utilities
num_or_zero() { v="$1"; [[ "$v" =~ ^[0-9]+$ ]] && echo "$v" || echo 0; }

# ---- JSON extraction utilities ----
# Pure bash JSON value extractor (fallback when jq not available)
extract_json_string() {
  local json="$1"
  local key="$2"
  local default="${3:-}"
  
  # For nested keys like workspace.current_dir, get the last part
  local field="${key##*.}"
  field="${field%% *}"  # Remove any jq operators
  
  # Try to extract string value (quoted)
  local value=$(echo "$json" | grep -o "\"\${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')
  
  # Convert escaped backslashes to forward slashes for Windows paths
  if [ -n "$value" ]; then
    value=$(echo "$value" | sed 's/\\\\/\//g')
  fi
  
  # If no string value found, try to extract number value (unquoted)
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    value=$(echo "$json" | grep -o "\"\${field}\"[[:space:]]*:[[:space:]]*[0-9.]\+" | head -1 | sed 's/.*:[[:space:]]*\([0-9.]\+\).*/\1/')
  fi
  
  # Return value or default
  if [ -n "$value" ] && [ "$value" != "null" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

# ---- basics ----
if [ "$HAS_JQ" -eq 1 ]; then
  current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "unknown"' 2>/dev/null | sed "s|^$HOME|~|g")
  model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null)
  model_version=$(echo "$input" | jq -r '.model.version // ""' 2>/dev/null)
  session_id=$(echo "$input" | jq -r '.session_id // ""' 2>/dev/null)
  cc_version=$(echo "$input" | jq -r '.version // ""' 2>/dev/null)
  output_style=$(echo "$input" | jq -r '.output_style.name // ""' 2>/dev/null)
else
  # Bash fallback for JSON extraction
  # Extract current_dir from workspace object - look for the pattern workspace":{"current_dir":"..."}
  current_dir=$(echo "$input" | grep -o '"workspace"[[:space:]]*:[[:space:]]*{[^}]*"current_dir"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"current_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | sed 's/\\\\/\//g')
  
  # Fall back to cwd if workspace extraction failed
  if [ -z "$current_dir" ] || [ "$current_dir" = "null" ]; then
    current_dir=$(echo "$input" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | sed 's/\\\\/\//g')
  fi
  
  # Fallback to unknown if all extraction failed
  [ -z "$current_dir" ] && current_dir="unknown"
  current_dir=$(echo "$current_dir" | sed "s|^$HOME|~|g")
  
  # Extract model name from nested model object
  model_name=$(echo "$input" | grep -o '"model"[[:space:]]*:[[:space:]]*{[^}]*"display_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  [ -z "$model_name" ] && model_name="Claude"
  # Model version is in the model ID, not a separate field  
  model_version=""  # Not available in Claude Code JSON
  session_id=$(extract_json_string "$input" "session_id" "")
  # CC version is at the root level
  cc_version=$(echo "$input" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  # Output style is nested
  output_style=$(echo "$input" | grep -o '"output_style"[[:space:]]*:[[:space:]]*{[^}]*"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

# ---- git colors ----
git_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;150m'; fi; }  # soft green
git_clean_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;120m'; fi; }  # bright green
git_dirty_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;203m'; fi; }  # coral red
git_ahead_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;75m'; fi; }   # cyan
git_behind_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;220m'; fi; } # yellow

# ---- enhanced git with caching ----
get_git_info() {
  local cache_file="$CACHE_DIR/git_info_$(pwd | sed 's/\//_/g')"
  
  if is_cache_valid "$cache_file"; then
    read_cache "$cache_file"
    return
  fi
  
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    write_cache "$cache_file" ""
    return
  fi
  
  local git_branch git_status git_ahead git_behind
  
  # Get branch name
  git_branch=$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
  
  # Check if working tree is clean
  if git diff-index --quiet HEAD -- 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    git_status="clean"
  else
    git_status="dirty"
  fi
  
  # Get ahead/behind counts (skip locks for performance)
  local remote_info
  remote_info=$(git status --porcelain=v2 --branch --ahead-behind 2>/dev/null | grep '^# branch\.ab' | head -1)
  if [ -n "$remote_info" ]; then
    git_ahead=$(echo "$remote_info" | cut -d' ' -f3)
    git_behind=$(echo "$remote_info" | cut -d' ' -f4)
  else
    git_ahead="0"
    git_behind="0"
  fi
  
  # Format output
  local result="$git_branch|$git_status|$git_ahead|$git_behind"
  write_cache "$cache_file" "$result"
  echo "$result"
}

git_info=$(get_git_info)
if [ -n "$git_info" ]; then
  git_branch=$(echo "$git_info" | cut -d'|' -f1)
  git_status=$(echo "$git_info" | cut -d'|' -f2)
  git_ahead=$(echo "$git_info" | cut -d'|' -f3)
  git_behind=$(echo "$git_info" | cut -d'|' -f4)
else
  git_branch=""
  git_status=""
  git_ahead="0"
  git_behind="0"
fi

# ---- context window calculation with enhanced color coding ----
context_pct=""
context_color() { if [ "$use_color" -eq 1 ]; then printf '\033[1;37m'; fi; }  # default white

# Determine max context based on model
get_max_context() {
  local model_name="$1"
  case "$model_name" in
    *"Opus 4"*|*"opus 4"*|*"Opus"*|*"opus"*)
      echo "200000"  # 200K for all Opus versions
      ;;
    *"Sonnet 4"*|*"sonnet 4"*|*"Sonnet 3.5"*|*"sonnet 3.5"*|*"Sonnet"*|*"sonnet"*)
      echo "200000"  # 200K for Sonnet 3.5+ and 4.x
      ;;
    *"Haiku 3.5"*|*"haiku 3.5"*|*"Haiku 4"*|*"haiku 4"*|*"Haiku"*|*"haiku"*)
      echo "200000"  # 200K for modern Haiku
      ;;
    *"Claude 3 Haiku"*|*"claude 3 haiku"*)
      echo "100000"  # 100K for original Claude 3 Haiku
      ;;
    *)
      echo "200000"  # Default to 200K
      ;;
  esac
}

if [ -n "$session_id" ] && [ "$HAS_JQ" -eq 1 ]; then
  MAX_CONTEXT=$(get_max_context "$model_name")
  
  # Convert current dir to session file path
  project_dir=$(echo "$current_dir" | sed "s|~|$HOME|g" | sed 's|/|-|g' | sed 's|^-||')
  session_file="$HOME/.claude/projects/-${project_dir}/${session_id}.jsonl"
  
  if [ -f "$session_file" ]; then
    # Get the latest input token count from the session file
    latest_tokens=$(tail -20 "$session_file" | jq -r 'select(.message.usage) | .message.usage | ((.input_tokens // 0) + (.cache_read_input_tokens // 0))' 2>/dev/null | tail -1)
    
    if [ -n "$latest_tokens" ] && [ "$latest_tokens" -gt 0 ]; then
      context_used_pct=$(( latest_tokens * 100 / MAX_CONTEXT ))
      context_remaining_pct=$(( 100 - context_used_pct ))
      
      # Enhanced color coding for context usage
      if [ "$context_remaining_pct" -gt 50 ]; then
        context_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;118m'; fi; }  # bright green
      elif [ "$context_remaining_pct" -gt 20 ]; then
        context_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;226m'; fi; }  # bright yellow
      else
        context_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;196m'; fi; }  # bright red
      fi
      
      context_pct="${context_remaining_pct}%"
    fi
  fi
fi

# ---- usage colors ----
usage_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;189m'; fi; }  # lavender
cost_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;222m'; fi; }   # light gold
burn_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;220m'; fi; }   # bright gold
session_color() { 
  rem_pct=$(( 100 - session_pct ))
  if   (( rem_pct <= 10 )); then SCLR='38;5;210'  # light pink
  elif (( rem_pct <= 25 )); then SCLR='38;5;228'  # light yellow  
  else                          SCLR='38;5;194'; fi  # light green
  if [ "$use_color" -eq 1 ]; then printf '\033[%sm' "$SCLR"; fi
}

# ---- cost and usage extraction ----
session_txt=""; session_pct=0; session_bar=""
cost_usd=""; cost_per_hour=""; tpm=""; tot_tokens=""

# Extract cost data from Claude Code input
if [ "$HAS_JQ" -eq 1 ]; then
  # Get cost data from Claude Code's input
  cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
  total_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty' 2>/dev/null)
  
  # Calculate burn rate ($/hour) from cost and duration
  if [ -n "$cost_usd" ] && [ -n "$total_duration_ms" ] && [ "$total_duration_ms" -gt 0 ]; then
    # Convert ms to hours and calculate rate
    cost_per_hour=$(echo "$cost_usd $total_duration_ms" | awk '{printf "%.2f", $1 * 3600000 / $2}')
  fi
else
  # Bash fallback for cost extraction
  cost_usd=$(echo "$input" | grep -o '"total_cost_usd"[[:space:]]*:[[:space:]]*[0-9.]*' | sed 's/.*:[[:space:]]*\([0-9.]*\).*/\1/')
  total_duration_ms=$(echo "$input" | grep -o '"total_duration_ms"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/.*:[[:space:]]*\([0-9]*\).*/\1/')  
  
  # Calculate burn rate ($/hour) from cost and duration
  if [ -n "$cost_usd" ] && [ -n "$total_duration_ms" ] && [ "$total_duration_ms" -gt 0 ]; then
    # Convert ms to hours and calculate rate
    cost_per_hour=$(echo "$cost_usd $total_duration_ms" | awk '{printf "%.2f", $1 * 3600000 / $2}')
  fi
fi

# ---- project name detection ----
get_project_name() {
  local cache_file="$CACHE_DIR/project_name_$(pwd | sed 's/\//_/g')"
  
  if is_cache_valid "$cache_file"; then
    read_cache "$cache_file"
    return
  fi
  
  local project_name=""
  
  # Try git repo name first
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$git_root" ]; then
      project_name=$(basename "$git_root")
    fi
  fi
  
  # Fallback to current directory name
  if [ -z "$project_name" ]; then
    project_name=$(basename "$(pwd)")
  fi
  
  write_cache "$cache_file" "$project_name"
  echo "$project_name"
}

project_name=$(get_project_name)

# ---- language detection ----
get_primary_language() {
  local cache_file="$CACHE_DIR/language_$(pwd | sed 's/\//_/g')"
  
  if is_cache_valid "$cache_file"; then
    read_cache "$cache_file"
    return
  fi
  
  local lang_result=""
  
  # Count file extensions in current directory and git repo
  local file_counts=""
  if git rev-parse --git-dir >/dev/null 2>&1; then
    # Get from git repo
    file_counts=$(git ls-files 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -5)
  else
    # Get from current directory
    file_counts=$(find . -maxdepth 2 -type f -name "*.*" 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -5)
  fi
  
  if [ -n "$file_counts" ]; then
    local top_ext=$(echo "$file_counts" | head -1 | awk '{print $2}')
    case "$top_ext" in
      py) lang_result="🐍 Python" ;;
      js|jsx|ts|tsx) lang_result="📜 JavaScript/TypeScript" ;;
      rs) lang_result="🦀 Rust" ;;
      java) lang_result="☕ Java" ;;
      go) lang_result="🐹 Go" ;;
      cpp|cc|cxx|c) lang_result="⚙️ C/C++" ;;
      rb) lang_result="💎 Ruby" ;;
      php) lang_result="🐘 PHP" ;;
      sh|bash|zsh) lang_result="🐚 Shell" ;;
      swift) lang_result="🦉 Swift" ;;
      kt) lang_result="🎯 Kotlin" ;;
      dart) lang_result="🎯 Dart" ;;
      html|htm) lang_result="🌐 HTML" ;;
      css|scss|sass) lang_result="🎨 CSS" ;;
      json|yaml|yml) lang_result="⚙️ Config" ;;
      md) lang_result="📝 Markdown" ;;
      *) lang_result="" ;;
    esac
  fi
  
  write_cache "$cache_file" "$lang_result"
  echo "$lang_result"
}

primary_language=$(get_primary_language)

# ---- session duration tracking ----
get_session_duration() {
  if [ -z "$session_id" ]; then
    echo ""
    return
  fi
  
  local cache_file="$CACHE_DIR/session_dur_${session_id}"
  
  if is_cache_valid "$cache_file"; then
    read_cache "$cache_file"
    return
  fi
  
  # Get session start time from session file
  local project_dir_path=$(echo "$current_dir" | sed "s|~|$HOME|g" | sed 's|/|-|g' | sed 's|^-||')
  local session_file="$HOME/.claude/projects/-${project_dir_path}/${session_id}.jsonl"
  
  if [ -f "$session_file" ]; then
    local start_time=""
    if [ "$HAS_JQ" -eq 1 ]; then
      start_time=$(head -1 "$session_file" | jq -r '.timestamp // empty' 2>/dev/null)
    else
      # Bash fallback for timestamp extraction
      start_time=$(head -1 "$session_file" | grep -o '"timestamp"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"timestamp"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    fi
    
    if [ -n "$start_time" ]; then
      local start_epoch=$(to_epoch "$start_time")
      local current_epoch=$(date +%s)
      if [ -n "$start_epoch" ] && [ "$start_epoch" -gt 0 ]; then
        local duration_sec=$((current_epoch - start_epoch))
        local hours=$((duration_sec / 3600))
        local minutes=$(((duration_sec % 3600) / 60))
        local duration_text="${hours}h ${minutes}m"
        write_cache "$cache_file" "$duration_text"
        echo "$duration_text"
        return
      fi
    fi
  fi
  
  write_cache "$cache_file" ""
  echo ""
}

session_duration=$(get_session_duration)

# ---- todo count from Claude's todo system ----
get_todo_count() {
  local cache_file="$CACHE_DIR/todo_count"
  
  if is_cache_valid "$cache_file"; then
    read_cache "$cache_file"
    return
  fi
  
  local todo_count=""
  
  # Check if there's a .claude/todos file or todo tracking
  if [ -f "$HOME/.claude/todos.json" ]; then
    if [ "$HAS_JQ" -eq 1 ]; then
      local active_todos=$(jq '[.[] | select(.completed != true)] | length' "$HOME/.claude/todos.json" 2>/dev/null)
      if [ -n "$active_todos" ] && [ "$active_todos" -gt 0 ]; then
        todo_count="$active_todos"
      fi
    else
      # Simple bash fallback: count lines that don't have "completed":true
      local active_todos=$(grep -c '"completed"[[:space:]]*:[[:space:]]*true' "$HOME/.claude/todos.json" 2>/dev/null || echo 0)
      local total_todos=$(grep -c '"id"[[:space:]]*:' "$HOME/.claude/todos.json" 2>/dev/null || echo 0)
      local incomplete_todos=$((total_todos - active_todos))
      if [ "$incomplete_todos" -gt 0 ]; then
        todo_count="$incomplete_todos"
      fi
    fi
  fi
  
  write_cache "$cache_file" "$todo_count"
  echo "$todo_count"
}

todo_count=$(get_todo_count)

# Get token data and session info from ccusage if available
if command -v ccusage >/dev/null 2>&1 && [ "$HAS_JQ" -eq 1 ]; then
  blocks_output=""
  
  # Try ccusage with timeout for token data and session info
  if command -v timeout >/dev/null 2>&1; then
    blocks_output=$(timeout 5s ccusage blocks --json 2>/dev/null)
  elif command -v gtimeout >/dev/null 2>&1; then
    # macOS with coreutils installed
    blocks_output=$(gtimeout 5s ccusage blocks --json 2>/dev/null)
  else
    # No timeout available, run directly (ccusage should be fast)
    blocks_output=$(ccusage blocks --json 2>/dev/null)
  fi
  if [ -n "$blocks_output" ]; then
    active_block=$(echo "$blocks_output" | jq -c '.blocks[] | select(.isActive == true)' 2>/dev/null | head -n1)
    if [ -n "$active_block" ]; then
      # Get token count from ccusage
      tot_tokens=$(echo "$active_block" | jq -r '.totalTokens // empty')
      # Get tokens per minute from ccusage
      tpm=$(echo "$active_block" | jq -r '.burnRate.tokensPerMinute // empty')
      
      # Session time calculation from ccusage
      reset_time_str=$(echo "$active_block" | jq -r '.usageLimitResetTime // .endTime // empty')
      start_time_str=$(echo "$active_block" | jq -r '.startTime // empty')
      
      if [ -n "$reset_time_str" ] && [ -n "$start_time_str" ]; then
        start_sec=$(to_epoch "$start_time_str"); end_sec=$(to_epoch "$reset_time_str"); now_sec=$(date +%s)
        total=$(( end_sec - start_sec )); (( total<1 )) && total=1
        elapsed=$(( now_sec - start_sec )); (( elapsed<0 ))&&elapsed=0; (( elapsed>total ))&&elapsed=$total
        session_pct=$(( elapsed * 100 / total ))
        remaining=$(( end_sec - now_sec )); (( remaining<0 )) && remaining=0
        rh=$(( remaining / 3600 )); rm=$(( (remaining % 3600) / 60 ))
        end_hm=$(fmt_time_hm "$end_sec")
        session_txt="$(printf '%dh %dm until reset at %s (%d%%)' "$rh" "$rm" "$end_hm" "$session_pct")"
        session_bar=$(progress_bar "$session_pct" 10)
      fi
    fi
  fi
fi

# ---- per-message token usage (from context_window.current_usage) ----
token_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;116m'; fi; }  # teal
token_dim_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;245m'; fi; }  # gray

format_tokens() {
  local n="$1"
  if [ "$n" -ge 1000000 ]; then
    printf '%.1fM' "$(echo "$n" | awk '{printf "%.1f", $1/1000000}')"
  elif [ "$n" -ge 1000 ]; then
    printf '%.1fk' "$(echo "$n" | awk '{printf "%.1f", $1/1000}')"
  else
    printf '%d' "$n"
  fi
}

get_last_input_tokens() {
  if [ "$HAS_JQ" -eq 1 ]; then
    echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty' 2>/dev/null
  else
    echo "$input" | grep -o '"input_tokens"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$'
  fi
}

get_last_output_tokens() {
  if [ "$HAS_JQ" -eq 1 ]; then
    echo "$input" | jq -r '.context_window.current_usage.output_tokens // empty' 2>/dev/null
  else
    echo "$input" | grep -o '"output_tokens"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$'
  fi
}

get_cache_read_tokens() {
  if [ "$HAS_JQ" -eq 1 ]; then
    echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // empty' 2>/dev/null
  fi
}

get_cache_creation_tokens() {
  if [ "$HAS_JQ" -eq 1 ]; then
    echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // empty' 2>/dev/null
  fi
}

get_total_input_tokens() {
  if [ "$HAS_JQ" -eq 1 ]; then
    echo "$input" | jq -r '.context_window.total_input_tokens // empty' 2>/dev/null
  else
    echo "$input" | grep -o '"total_input_tokens"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$'
  fi
}

get_total_output_tokens() {
  if [ "$HAS_JQ" -eq 1 ]; then
    echo "$input" | jq -r '.context_window.total_output_tokens // empty' 2>/dev/null
  else
    echo "$input" | grep -o '"total_output_tokens"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$'
  fi
}

# ---- detect shell type ----
get_shell_type() {
  if [ -n "$BASH_VERSION" ]; then
    echo "bash"
  elif [ -n "$ZSH_VERSION" ]; then
    echo "zsh"
  else
    echo "$(basename "$SHELL")"
  fi
}

shell_type=$(get_shell_type)
shell_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;159m'; fi; }  # light cyan

# ---- render enhanced statusline ----
# Line 1: Core info - directory, shell, model, version, output style, context
# Show just the current directory name (basename)
current_dir_name=$(basename "$(echo "$current_dir" | sed "s|~|$HOME|g")")
printf '📁 %s%s%s' "$(dir_color)" "$current_dir_name" "$(rst)"

printf '  🤖 %s%s%s' "$(model_color)" "$model_name" "$(rst)"

if [ -n "$cc_version" ] && [ "$cc_version" != "null" ]; then
  printf '  📟 %sv%s%s' "$(cc_version_color)" "$cc_version" "$(rst)"
fi

# Statusline version + update notification
update_avail=""
if [ -f "$CACHE_DIR/update_available" ]; then
  update_avail=$(cat "$CACHE_DIR/update_available")
fi
if [ -n "$update_avail" ]; then
  update_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;208m'; fi; }  # orange
  printf '  %s⬆ SL v%s → v%s%s' "$(update_color)" "$STATUSLINE_VERSION" "$update_avail" "$(rst)"
else
  printf '  %sSL v%s%s' "$(style_color)" "$STATUSLINE_VERSION" "$(rst)"
fi

# Usage display (session + weekly with separate reset times)
session_usage=$(get_session_usage)
weekly_usage=$(get_weekly_usage)
session_reset=$(get_session_reset_time)
weekly_reset=$(get_weekly_reset_time)

# Color helper based on usage level
usage_color_for() {
  local pct="$1"
  if [ "$pct" -lt 50 ]; then
    if [ "$use_color" -eq 1 ]; then printf '\033[38;5;118m'; fi  # green
  elif [ "$pct" -lt 75 ]; then
    if [ "$use_color" -eq 1 ]; then printf '\033[38;5;226m'; fi  # yellow
  else
    if [ "$use_color" -eq 1 ]; then printf '\033[38;5;196m'; fi  # red
  fi
}

# Reset time color (gray)
reset_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;245m'; fi; }

# No stale indicator needed - data comes from live statusline JSON

if [ -n "$session_usage" ] && [[ "$session_usage" =~ ^[0-9]+$ ]] && [ -n "$weekly_usage" ] && [[ "$weekly_usage" =~ ^[0-9]+$ ]]; then
  session_bar=$(progress_bar "$session_usage" 6)
  weekly_bar=$(progress_bar "$weekly_usage" 6)

  # Format session reset
  session_reset_txt=""
  if [ -n "$session_reset" ] && [ "$session_reset" != "expired" ]; then
    session_reset_txt=" $(reset_color)⏱${session_reset}$(rst)"
  fi

  # Format weekly reset
  weekly_reset_txt=""
  if [ -n "$weekly_reset" ] && [ "$weekly_reset" != "expired" ]; then
    weekly_reset_txt=" $(reset_color)⏱${weekly_reset}$(rst)"
  fi

  printf '\n⚡ %sSession: %d%% [%s]%s%s  📈 %sWeekly: %d%% [%s]%s%s' \
    "$(usage_color_for "$session_usage")" "$session_usage" "$session_bar" "$(rst)" "$session_reset_txt" \
    "$(usage_color_for "$weekly_usage")" "$weekly_usage" "$weekly_bar" "$(rst)" "$weekly_reset_txt"
elif [ -n "$weekly_usage" ] && [[ "$weekly_usage" =~ ^[0-9]+$ ]]; then
  # Fallback: only weekly usage available
  weekly_bar=$(progress_bar "$weekly_usage" 10)
  weekly_reset_txt=""
  if [ -n "$weekly_reset" ] && [ "$weekly_reset" != "expired" ]; then
    weekly_reset_txt=" $(reset_color)⏱${weekly_reset}$(rst)"
  fi
  printf '\n📈 %sWeekly: %d%% [%s]%s%s' "$(usage_color_for "$weekly_usage")" "$weekly_usage" "$weekly_bar" "$(rst)" "$weekly_reset_txt"
fi

# Per-message and session token usage
last_in=$(get_last_input_tokens)
last_out=$(get_last_output_tokens)
cache_read=$(get_cache_read_tokens)
cache_create=$(get_cache_creation_tokens)
sess_in=$(get_total_input_tokens)
sess_out=$(get_total_output_tokens)

# Line 3: Cached, total tokens, git, session duration
line3=""

if [ -n "$cache_read" ] && [[ "$cache_read" =~ ^[0-9]+$ ]] && [ "$cache_read" -gt 0 ]; then
  line3="$(token_dim_color)📦 Cached: $(format_tokens "$cache_read")$(rst)"
fi

if [ -n "$sess_in" ] && [[ "$sess_in" =~ ^[0-9]+$ ]] && [ -n "$sess_out" ] && [[ "$sess_out" =~ ^[0-9]+$ ]]; then
  sess_total=$((sess_in + sess_out))
  session_tok_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;183m'; fi; }
  [ -n "$line3" ] && line3="$line3  "
  line3="${line3}$(session_tok_color)📊 Total: $(format_tokens "$sess_total")$(rst)"
fi

# Git info
if [ -n "$git_branch" ]; then
  [ -n "$line3" ] && line3="$line3  "
  line3="${line3}🌿 $(git_color)${git_branch}$(rst)"
  if [ "$git_status" = "clean" ]; then
    line3="$line3 $(git_clean_color)✅$(rst)"
  elif [ "$git_status" = "dirty" ]; then
    line3="$line3 $(git_dirty_color)❌$(rst)"
  fi
  if [ "$git_ahead" -gt 0 ]; then
    line3="$line3 $(git_ahead_color)↑$git_ahead$(rst)"
  fi
  if [ "$git_behind" -gt 0 ]; then
    line3="$line3 $(git_behind_color)↓$git_behind$(rst)"
  fi
fi

# Session duration
if [ -n "$session_duration" ]; then
  [ -n "$line3" ] && line3="$line3  "
  line3="${line3}⏱️ $(session_dur_color)${session_duration}$(rst)"
fi

# Print line 3
if [ -n "$line3" ]; then
  printf '\n%s' "$line3"
fi
printf '\n'
