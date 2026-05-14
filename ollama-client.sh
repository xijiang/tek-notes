#!/bin/bash

# --- Configuration ---
OLLAMA_HOST_IP="10.42.191.20"
HOST_LINE="export OLLAMA_HOST=\"$OLLAMA_HOST_IP\""
BASHRC="$HOME/.bashrc"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_LIB="$HOME/.local/lib/node_tools"

# Ensure local directories exist
mkdir -p "$LOCAL_BIN"
mkdir -p "$LOCAL_LIB"

# Detect Architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo ">>> Starting Standalone Tool Installer (Arch: $ARCH)..."

# --- 1. Configure Bash ---
if ! grep -Fq "$OLLAMA_HOST_IP" "$BASHRC"; then
    echo -e "\n# Ollama Client Configuration\n$HOST_LINE" >> "$BASHRC"
    echo ">>> Configured OLLAMA_HOST in $BASHRC"
fi

# --- 2. Install/Update Ollama Binary ---
echo ">>> Checking Ollama..."
LATEST_OLLAMA=$(curl -s https://api.github.com/repos/ollama/ollama/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
CURRENT_OLLAMA=$("$LOCAL_BIN/ollama" --version 2>/dev/null | awk '{print $NF}')

if [ "$CURRENT_OLLAMA" != "$LATEST_OLLAMA" ]; then
    echo ">>> Downloading Ollama $LATEST_OLLAMA..."
    curl -L "https://ollama.com/download/ollama-linux-${ARCH}.tar.zst" | zstd -d | tar -xf - -C "$HOME/.local"
else
    echo ">>> Ollama is up to date ($CURRENT_OLLAMA)."
fi

# --- 3. Install/Update CLI Tools (Node.js) ---
# We install into a dedicated local lib folder so it's portable
manage_node_tool() {
    local pkg=$1
    local cmd=$2
    echo ">>> Checking $pkg..."
    npm install --prefix "$LOCAL_LIB" "$pkg@latest" --no-save --quiet
    ln -sf "$LOCAL_LIB/node_modules/.bin/$cmd" "$LOCAL_BIN/$cmd"
}

if command -v npm >/dev/null; then
    manage_node_tool "@google/gemini-cli" "gemini"
    manage_node_tool "@github/copilot" "copilot"
    manage_node_tool "pi" "pi"
else
    echo ">>> Skipping Node tools (npm not found)."
fi

# --- 4. Install/Update Pip Tools ---
if command -v pip >/dev/null; then
    echo ">>> Checking marker-pdf..."
    pip install --user --upgrade "marker-pdf[full]" --quiet
else
    echo ">>> Skipping Pip tools (pip not found)."
fi

echo "-------------------------------------------------------"
echo ">>> Done! All tools installed to $HOME/.local/bin"
echo ">>> IMPORTANT: Run 'source ~/.bashrc' to apply changes."
echo ">>> Your Ollama client is pointing to: $OLLAMA_HOST_IP"
