#!/bin/zsh
# macOS: double-click to run in Terminal (may first require chmod +x run.command).
cd "$(dirname "$0")"
zsh ./capture_lab16.sh
result=$?
echo
if [[ $result -eq 0 ]]; then
    echo 'Lab 16 finished successfully.'
else
    echo 'Lab 16 did not finish. See output/results.txt and output/session.txt.'
fi
echo 'Press Return to close this window.'
read -r
exit "$result"
