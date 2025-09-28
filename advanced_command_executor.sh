#!/bin/bash
# advanced_command_executor.sh - Sistema avanzato di esecuzione comandi con retry

set -e
set -u

# Configurazioni globali
SUDO_PASS="SS1-Temp1234"
MAX_RETRIES=5
RETRY_DELAY=10
TIMEOUT_SECONDS=600
BASE_LOG_DIR="logs/monitoring"

# Funzione di logging strutturato
structured_log() {
    local level="$1"
    local component="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local log_entry="{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"component\":\"$component\",\"message\":\"$message\"}"

    mkdir -p "$BASE_LOG_DIR"
    echo "$log_entry" | tee -a "$BASE_LOG_DIR/structured.log"
    echo "[$timestamp] [$level] [$component] $message" | tee -a "$BASE_LOG_DIR/readable.log"
}

# Funzione di controllo errori avanzata
advanced_error_handler() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    local attempt="$4"
    local max_attempts="$5"

    structured_log "ERROR" "COMMAND_EXECUTOR" "Command failed: $command (attempt $attempt/$max_attempts, exit code $exit_code, line $line_number)"

    if [ $attempt -lt $max_attempts ]; then
        structured_log "INFO" "RETRY_HANDLER" "Retrying command in $RETRY_DELAY seconds (attempt $(($attempt + 1))/$max_attempts)"
        sleep $RETRY_DELAY
        return 0  # Continue retry loop
    else
        structured_log "CRITICAL" "COMMAND_EXECUTOR" "Command failed permanently after $max_attempts attempts: $command"
        return 1  # Exit retry loop
    fi
}

# Esecutore di comandi con retry automatico
execute_command_with_retry() {
    local command="$1"
    local description="$2"
    local component="${3:-GENERAL}"
    local log_file="$BASE_LOG_DIR/${component,,}_$(date +%Y%m%d_%H%M%S).log"

    mkdir -p "$BASE_LOG_DIR"
    structured_log "INFO" "$component" "Starting: $description"

    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        structured_log "INFO" "$component" "Executing command (attempt $attempt/$MAX_RETRIES): $command"

        # Esegui comando con timeout e cattura output
        if timeout $TIMEOUT_SECONDS bash -c "$command" > "$log_file" 2>&1; then
            structured_log "SUCCESS" "$component" "Command completed successfully: $description"

            # Analizza il log per warnings
            if grep -qi "warning\|warn" "$log_file"; then
                structured_log "WARNING" "$component" "Command completed with warnings, check log: $log_file"
            fi

            return 0
        else
            local exit_code=$?

            # Analizza il log per dettagli dell'errore
            local error_details=""
            if [ -f "$log_file" ]; then
                error_details=$(tail -n 5 "$log_file" | tr '\n' ' ')
            fi

            structured_log "ERROR" "$component" "Command failed with exit code $exit_code: $error_details"

            if ! advanced_error_handler $exit_code $LINENO "$command" $attempt $MAX_RETRIES; then
                return 1
            fi

            ((attempt++))
        fi
    done

    return 1
}

# Funzione sudo con retry
sudo_cmd_retry() {
    local cmd="$*"
    execute_command_with_retry "echo '$SUDO_PASS' | sudo -S $cmd 2>/dev/null || sudo $cmd" "Sudo command: $cmd" "SUDO"
}