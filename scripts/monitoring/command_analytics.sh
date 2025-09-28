#!/bin/bash
# command_analytics.sh - Sistema di analytics per comandi bash

set -e
set -u

ANALYTICS_LOG_DIR="logs/analytics"
COMMAND_STATS_FILE="$ANALYTICS_LOG_DIR/command_stats.json"
EXECUTION_LOG_FILE="$ANALYTICS_LOG_DIR/execution_history.log"

mkdir -p "$ANALYTICS_LOG_DIR"

# Funzione per registrare statistiche comando
record_command_execution() {
    local command="$1"
    local exit_code="$2"
    local duration="$3"
    local component="$4"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

    # Crea entry JSON per statistiche
    local stats_entry="{
        \"timestamp\": \"$timestamp\",
        \"command\": \"$command\",
        \"component\": \"$component\",
        \"exit_code\": $exit_code,
        \"duration_seconds\": $duration,
        \"success\": $([ $exit_code -eq 0 ] && echo 'true' || echo 'false')
    }"

    echo "$stats_entry" >> "$COMMAND_STATS_FILE"
    echo "[$timestamp] [$component] Command: $command | Exit: $exit_code | Duration: ${duration}s" >> "$EXECUTION_LOG_FILE"
}

# Funzione per generare report analytics
generate_analytics_report() {
    local report_file="$ANALYTICS_LOG_DIR/analytics_report_$(date +%Y%m%d_%H%M%S).md"

    echo "# InsightLearn.Cloud - Command Analytics Report" > "$report_file"
    echo "" >> "$report_file"
    echo "**Generated:** $(date)" >> "$report_file"
    echo "" >> "$report_file"

    if [ -f "$COMMAND_STATS_FILE" ]; then
        local total_commands=$(wc -l < "$COMMAND_STATS_FILE")
        local failed_commands=$(grep '"success": false' "$COMMAND_STATS_FILE" | wc -l || echo "0")
        local success_rate=100

        if [ $total_commands -gt 0 ]; then
            success_rate=$(echo "scale=2; (($total_commands - $failed_commands) * 100) / $total_commands" | bc -l 2>/dev/null || echo "100")
        fi

        echo "## 📊 Summary Statistics" >> "$report_file"
        echo "" >> "$report_file"
        echo "- **Total Commands Executed:** $total_commands" >> "$report_file"
        echo "- **Successful Commands:** $(($total_commands - $failed_commands))" >> "$report_file"
        echo "- **Failed Commands:** $failed_commands" >> "$report_file"
        echo "- **Success Rate:** $success_rate%" >> "$report_file"
        echo "" >> "$report_file"

        # Top failing commands
        echo "## ❌ Most Failed Commands" >> "$report_file"
        echo "" >> "$report_file"
        if [ $failed_commands -gt 0 ]; then
            grep '"success": false' "$COMMAND_STATS_FILE" | head -10 >> "$report_file" 2>/dev/null || echo "Unable to process failure statistics" >> "$report_file"
        else
            echo "No failed commands found!" >> "$report_file"
        fi
        echo "" >> "$report_file"

        # Recent executions
        echo "## 📝 Recent Command Executions" >> "$report_file"
        echo "" >> "$report_file"
        if [ -f "$EXECUTION_LOG_FILE" ]; then
            echo '```' >> "$report_file"
            tail -20 "$EXECUTION_LOG_FILE" >> "$report_file" 2>/dev/null || echo "No execution history found" >> "$report_file"
            echo '```' >> "$report_file"
        fi
    else
        echo "## ⚠️ No Data Available" >> "$report_file"
        echo "" >> "$report_file"
        echo "No command execution data found. Execute some monitored commands first." >> "$report_file"
    fi

    echo "Analytics report generated: $report_file"
    return 0
}

# Esporta funzioni per uso esterno
export -f record_command_execution
export -f generate_analytics_report

# Se script chiamato direttamente, genera report
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    generate_analytics_report
fi