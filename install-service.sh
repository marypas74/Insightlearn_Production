#!/bin/bash
# Script per installare il servizio systemd

echo "🔧 Installazione servizio systemd per InsightLearn..."
echo "Eseguire questi comandi con sudo:"
echo ""
echo "sudo mv /tmp/insightlearn.service /etc/systemd/system/"
echo "sudo systemctl daemon-reload"
echo "sudo systemctl enable insightlearn"
echo "sudo systemctl start insightlearn"
echo ""
echo "Per verificare lo stato:"
echo "sudo systemctl status insightlearn"