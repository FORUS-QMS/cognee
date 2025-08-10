#!/bin/bash

# Wait for Ollama to be ready
echo "Waiting for Ollama to start..."
until curl -s http://localhost:11434/ > /dev/null; do
    echo "Waiting for Ollama..."
    sleep 2
done

echo "Ollama is ready! Pulling required models..."

# Pull LLM model
echo "Pulling LLM model: llama3.2:3b"
ollama pull llama3.2:3b

# Pull embedding model
echo "Pulling embedding model: nomic-embed-text"
ollama pull nomic-embed-text

echo "All models pulled successfully!"

# List installed models
echo "Installed models:"
ollama list