#!/bin/bash
# production_command_executor.sh - Sistema finale per production deployment

set -e
set -u

# Configurazioni production
SUDO_PASS="SS1-Temp1234"
MAX_RETRIES=10
RETRY_DELAY=15
TIMEOUT_SECONDS=900
BASE_LOG_DIR="logs/production"
PRODUCTION_IP="192.168.1.103"
KUBE_USER="mpasqui"
KUBE_PASS="SS1-Temp1234"

# Enhanced logging per production
production_log() {
    local level="$1"
    local component="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local log_entry="{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"component\":\"$component\",\"message\":\"$message\",\"environment\":\"production\",\"ip\":\"$PRODUCTION_IP\"}"

    mkdir -p "$BASE_LOG_DIR"
    echo "$log_entry" | tee -a "$BASE_LOG_DIR/production.json"
    echo "[$timestamp] [PROD] [$level] [$component] $message" | tee -a "$BASE_LOG_DIR/production.log"

    # Critical alerts per production
    if [ "$level" = "CRITICAL" ]; then
        echo "🚨 PRODUCTION ALERT: $message" | wall 2>/dev/null || true
    fi
}

# Enhanced error handler per production
production_error_handler() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    local attempt="$4"
    local max_attempts="$5"

    production_log "ERROR" "PROD_EXECUTOR" "Production command failed: $command (attempt $attempt/$max_attempts, exit code $exit_code, line $line_number)"

    # Salva stato per recovery
    echo "{\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")\",\"command\":\"$command\",\"exit_code\":$exit_code,\"attempt\":$attempt}" >> "$BASE_LOG_DIR/failed_commands.json"

    if [ $attempt -lt $max_attempts ]; then
        local backoff_delay=$((RETRY_DELAY * attempt))
        production_log "INFO" "RETRY_HANDLER" "Retrying production command in ${backoff_delay}s (attempt $(($attempt + 1))/$max_attempts)"
        sleep $backoff_delay
        return 0
    else
        production_log "CRITICAL" "PROD_EXECUTOR" "PRODUCTION FAILURE: Command failed permanently after $max_attempts attempts: $command"

        # Emergency notification
        echo "$(date): CRITICAL PRODUCTION FAILURE - $command" >> "$BASE_LOG_DIR/critical_failures.log"
        return 1
    fi
}

# Esecutore production con enhanced retry
execute_production_command() {
    local command="$1"
    local description="$2"
    local component="${3:-PRODUCTION}"
    local is_critical="${4:-false}"
    local log_file="$BASE_LOG_DIR/${component,,}_$(date +%Y%m%d_%H%M%S).log"

    mkdir -p "$BASE_LOG_DIR"
    production_log "INFO" "$component" "PRODUCTION: Starting $description"

    local attempt=1
    local max_retries_local=$MAX_RETRIES

    # Critical commands get more retries
    if [ "$is_critical" = "true" ]; then
        max_retries_local=$((MAX_RETRIES * 2))
        production_log "INFO" "$component" "Critical command detected, using $max_retries_local max retries"
    fi

    while [ $attempt -le $max_retries_local ]; do
        production_log "INFO" "$component" "PRODUCTION EXEC (attempt $attempt/$max_retries_local): $command"

        # Pre-execution system check for critical commands
        if [ "$is_critical" = "true" ]; then
            if ! systemctl is-active docker > /dev/null 2>&1; then
                production_log "WARNING" "SYSTEM_CHECK" "Docker not active, attempting to start"
                echo "$SUDO_PASS" | sudo -S systemctl start docker || true
                sleep 5
            fi

            if ! kubectl cluster-info > /dev/null 2>&1; then
                production_log "WARNING" "SYSTEM_CHECK" "Kubernetes cluster not reachable"
            fi
        fi

        # Execute with enhanced timeout for production
        if timeout $TIMEOUT_SECONDS bash -c "$command" > "$log_file" 2>&1; then
            production_log "SUCCESS" "$component" "PRODUCTION SUCCESS: $description"

            # Enhanced log analysis for production
            if grep -qi "error\|failed\|exception" "$log_file"; then
                production_log "WARNING" "$component" "Command succeeded but log contains error keywords, manual review recommended: $log_file"
            fi

            if grep -qi "warning\|warn" "$log_file"; then
                production_log "INFO" "$component" "Command completed with warnings: $log_file"
            fi

            return 0
        else
            local exit_code=$?

            # Enhanced error analysis for production
            local error_context=""
            if [ -f "$log_file" ]; then
                error_context=$(tail -n 10 "$log_file" | grep -i "error\|failed\|exception" | head -3 | tr '\n' ' ')
            fi

            production_log "ERROR" "$component" "PRODUCTION ERROR (exit $exit_code): $error_context"

            if ! production_error_handler $exit_code $LINENO "$command" $attempt $max_retries_local; then
                return 1
            fi

            ((attempt++))
        fi
    done

    return 1
}

# Production sudo wrapper
sudo_production_cmd() {
    local cmd="$*"
    execute_production_command "echo '$SUDO_PASS' | sudo -S $cmd 2>/dev/null || sudo $cmd" "Production sudo: $cmd" "SUDO" "true"
}