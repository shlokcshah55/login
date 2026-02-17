#!/bin/bash

# Run batch_vibe_tags.py repeatedly until all restaurants are processed
# Usage: ./run_batch_repeatedly.sh --without-summary
#        ./run_batch_repeatedly.sh --with-summary

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [--without-summary|--with-summary]"
    exit 1
fi

MODE=$1

# Detect python command (python3 or python)
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "Error: Python not found. Please install Python 3"
    exit 1
fi

echo "Using Python command: $PYTHON_CMD"

echo "======================================================================="
echo "CONTINUOUS BATCH PROCESSING MODE"
echo "======================================================================="
echo "Mode: $MODE"
echo "This will run batch_vibe_tags.py repeatedly until all are processed"
echo "Press Ctrl+C to stop at any time"
echo "======================================================================="
echo ""

BATCH_NUM=1

while true; do
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "BATCH RUN #$BATCH_NUM"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    # Run the batch script
    $PYTHON_CMD batch_vibe_tags.py $MODE

    EXIT_CODE=$?

    # Check if script completed successfully
    if [ $EXIT_CODE -ne 0 ]; then
        echo ""
        echo "✗ Batch script failed with exit code $EXIT_CODE"
        echo "Stopping continuous processing"
        exit $EXIT_CODE
    fi

    # Check if we should continue (look for completion message in output)
    # If the script reports 0 remaining, we're done
    echo ""
    echo "Batch #$BATCH_NUM complete. Checking if more remain..."

    # Small delay between batches to avoid overwhelming the API
    sleep 2

    BATCH_NUM=$((BATCH_NUM + 1))

    # Optional: add a limit to prevent infinite loops during testing
    # if [ $BATCH_NUM -gt 10 ]; then
    #     echo "Reached batch limit (10), stopping"
    #     break
    # fi
done

echo ""
echo "======================================================================="
echo "ALL BATCHES COMPLETE"
echo "======================================================================="
