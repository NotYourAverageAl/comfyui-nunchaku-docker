#!/bin/bash
set -ex

# Optimization for Transformers
export TOKENIZERS_PARALLELISM=false

PYTHON_BIN="/opt/conda/envs/comfy/bin/python"
COMFY_PATH="/workspace/ComfyUI/main.py"
LOG_FILE="/workspace/comfyui.log"

# Clean up any old logs
> $LOG_FILE

echo "Checking environment..."
$PYTHON_BIN --version

echo "Launching ComfyUI with SageAttention and Manager..."
# We use --listen 0.0.0.0 for cloud access (Vast/RunPod)
# We use --use-sage-attention for the compiled speed boost
nohup $PYTHON_BIN $COMFY_PATH --listen 0.0.0.0 --use-sage-attention > $LOG_FILE 2>&1 &

# Capture PID
PROC_ID=$!

# Wait and verify
sleep 10
if pgrep -f "$COMFY_PATH" > /dev/null; then
    echo "ComfyUI started successfully (PID: $PROC_ID)"
    echo "Access the UI via the mapped port (usually 8188)"
    # Follow logs so the container stay alive and visible in cloud consoles
    tail -f $LOG_FILE
else
    echo "FAILED TO START. Printing log for debug:"
    cat $LOG_FILE
    exit 1
fi
