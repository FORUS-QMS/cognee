# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Cognee is a memory layer for AI agents that enables dynamic knowledge graph construction from various data sources. It provides an ECL (Extract, Cognify, Load) pipeline architecture for building intelligent memory systems that can understand relationships and context.

## Global MCP Server Setup

Cognee is configured as a global MCP (Model Context Protocol) server for Claude Code, making its tools available across all projects.

### Available MCP Tools
- **cognify**: Transform data into structured knowledge graphs
- **codify**: Analyze code repositories and build code graphs
- **search**: Query knowledge with multiple search types (GRAPH_COMPLETION, RAG_COMPLETION, etc.)
- **list_data**: List all datasets and data items
- **delete**: Remove specific data from datasets
- **prune**: Reset Cognee memory completely
- **cognify_status/codify_status**: Check processing status

### MCP Configuration
The Cognee MCP server is configured globally via:
- **Runner Script**: `~/bin/cognee-mcp-runner.sh`
- **Scope**: User-level (available across all projects)
- **Transport**: stdio (standard for Claude Code)

To verify MCP is working:
```bash
claude mcp list  # Should show cognee server
```

## Development Commands

### Installation & Setup
```bash
# Install with UV (recommended for development)
uv sync --all-extras

# Install with pip
pip install -e .

# Copy and configure environment variables
cp .env.template .env
# Edit .env with your LLM_API_KEY at minimum (or use Ollama setup below)
```

### Ollama Setup (Local LLMs)

Cognee supports using Ollama for both LLM inference and embeddings. **Note**: Cognee does NOT create custom embeddings in Ollama - it uses pre-existing embedding models from Ollama's model library.

### Basic Ollama Integration

#### 1. Install and Start Ollama
```bash
# Install Ollama (macOS/Linux)
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama server
ollama serve

# Or via Docker
docker run -d --name ollama -p 11434:11434 ollama/ollama
```

#### 2. Pull Required Models
```bash
# Pull LLM model (choose one)
ollama pull llama3.1:8b          # Smaller, faster
ollama pull phi4                  # Microsoft's efficient model
ollama pull mistral               # Good balance of speed/quality

# Pull embedding model (required for vector search)
ollama pull avr/sfr-embedding-mistral:latest  # 4096 dimensions
# Alternative embedding models:
# ollama pull nomic-embed-text     # 768 dimensions, faster
# ollama pull mxbai-embed-large    # 1024 dimensions
```

#### 3. Configure .env for Ollama
```bash
# LLM Configuration
LLM_API_KEY="ollama"
LLM_MODEL="llama3.1:8b"  # Must match pulled model name
LLM_PROVIDER="ollama"
LLM_ENDPOINT="http://localhost:11434/v1"

# Embedding Configuration
EMBEDDING_PROVIDER="ollama"
EMBEDDING_MODEL="avr/sfr-embedding-mistral:latest"  # Must match pulled model
EMBEDDING_ENDPOINT="http://localhost:11434/api/embeddings"
EMBEDDING_DIMENSIONS=4096  # Must match model dimensions
HUGGINGFACE_TOKENIZER="Salesforce/SFR-Embedding-Mistral"  # For tokenization
```

### Ollama MCP Integration

**Important Discovery**: Ollama can use MCP servers (not just Claude Code!) through community solutions:

1. **ollama-mcp-bridge**: TypeScript bridge connecting Ollama to any MCP server
2. **mcp-client-for-ollama (ollmcp)**: Python TUI with multi-server support
3. **Dolphin MCP**: Clean Python API for Ollama + MCP

This enables Ollama to directly access Cognee's knowledge graphs via MCP:

```bash
# Install MCP client for Ollama
pip install ollmcp

# Connect Ollama to Cognee MCP server
ollmcp stdio "~/bin/cognee-mcp-runner.sh"

# Now Ollama has access to all Cognee tools:
# - cognee.search()
# - cognee.cognify()
# - cognee.add()
# etc.
```

#### Key Points about Ollama in Cognee:
- **LLM Endpoint**: Uses OpenAI-compatible endpoint at `/v1`
- **Embedding Endpoint**: Uses Ollama's native endpoint at `/api/embeddings`
- **MCP Support**: Can connect to Cognee MCP server for knowledge access
- **Tokenizer**: Uses HuggingFace tokenizer for text chunking (not Ollama)
- **Dimensions**: Must match the actual embedding model dimensions
- **No Custom Embeddings**: Cognee uses standard Ollama models, doesn't train custom ones

### Running Tests
```bash
# Run basic library test
python cognee/tests/test_library.py

# Run specific test files with pytest
pytest cognee/tests/test_<name>.py

# Run with coverage
pytest --cov=cognee cognee/tests/

# Run async tests
pytest -m asyncio cognee/tests/
```

### Code Quality
```bash
# Format code with ruff
ruff format .

# Check linting issues
ruff check

# Fix auto-fixable issues
ruff check --fix

# Type checking with mypy
mypy cognee/
```

### Running Services
```bash
# Start Cognee API server (Docker)
docker-compose up cognee

# Start with specific profiles (Neo4j, Postgres, etc.)
docker-compose --profile postgres up
docker-compose --profile neo4j up

# Start Cognee GUI
python cognee-gui.py

# Start MCP server for Claude Code integration
docker-compose --profile mcp up cognee-mcp
```

## Architecture & Key Components

### Core Pipeline System
The system is built around a modular pipeline architecture located in `cognee/modules/pipelines/`:
- **Task**: Basic unit of work that can be chained together
- **Pipeline**: Orchestrates task execution with support for parallel processing
- **PipelineRun**: Tracks execution state and metrics

### Data Flow Architecture
1. **Ingestion** (`cognee/modules/ingestion/`): Handles various data types (text, PDF, images, audio)
2. **Chunking** (`cognee/modules/chunking/`): Breaks content into processable segments
3. **Graph Construction** (`cognee/tasks/graph/`): Extracts entities and relationships
4. **Storage** (`cognee/infrastructure/databases/`): Persists to vector, graph, and relational DBs
5. **Retrieval** (`cognee/modules/retrieval/`): Multiple retrieval strategies for search

### Database Abstraction Layer
The system supports multiple database backends through adapter patterns:
- **Vector DBs**: LanceDB (default), Qdrant, ChromaDB, PGVector
- **Graph DBs**: Kuzu (default), Neo4j, FalkorDB, Neptune Analytics
- **Relational**: SQLite (default), PostgreSQL

Database adapters are in `cognee/infrastructure/databases/` with interfaces defining common operations.

### LLM Integration
Located in `cognee/infrastructure/llm/`, supports multiple providers:
- OpenAI (default)
- Anthropic
- Ollama (local models)
- Gemini
- Generic LLM API

The system uses instructor for structured output extraction and includes rate limiting and retry logic.

## Key APIs

### Main User-Facing APIs (`cognee/api/v1/`)
- `add()`: Ingest data into the system
- `cognify()`: Process data into knowledge graphs
- `search()`: Query the knowledge base
- `delete()`: Remove data
- `prune()`: Clean up system resources

### Configuration
Environment variables are loaded from `.env` file. Key settings:
- `LLM_API_KEY`: Required for processing
- `DB_PROVIDER`: Choose relational database
- `GRAPH_DATABASE_PROVIDER`: Choose graph database
- `VECTOR_DB_PROVIDER`: Choose vector database

## Testing Strategy

### Test Organization
- Unit tests: `cognee/tests/unit/`
- Integration tests: `cognee/tests/integration/`
- Database-specific tests: `cognee/tests/test_<db_name>.py`
- Evaluation framework: `cognee/eval_framework/`

### Running Evaluations
The evaluation framework in `evals/` compares Cognee against other systems using benchmarks like HotpotQA.

## Common Development Tasks

### Adding a New Database Adapter
1. Create adapter in `cognee/infrastructure/databases/<type>/<name>/`
2. Implement the appropriate interface (e.g., `vector_db_interface.py`)
3. Register in `supported_databases.py`
4. Add configuration in `.env.template`
5. Create test file `cognee/tests/test_<name>.py`

### Creating a New Pipeline Task
1. Create task in `cognee/tasks/<category>/`
2. Define input/output models if needed
3. Register task in pipeline definitions
4. Add unit tests in `cognee/tests/tasks/`

### Modifying Graph Extraction
1. Core logic in `cognee/tasks/graph/extract_graph_from_data.py`
2. Graph models in `cognee/shared/data_models.py`
3. Entity extraction in `cognee/infrastructure/entities/`

## Docker Development

### Available Profiles
- `postgres`: PostgreSQL with pgvector
- `neo4j`: Neo4j graph database
- `falkordb`: FalkorDB graph database
- `chromadb`: ChromaDB vector database
- `ui`: Cognee frontend (work in progress)
- `mcp`: Model Context Protocol server for Claude Code

### Debugging
Debug ports are exposed:
- API: 5678
- MCP: 5678 (when using mcp profile)

Set `DEBUG=true` in docker-compose environment.

## Important Patterns

### Async-First Design
Most operations are async. Use `asyncio.run()` for synchronous contexts:
```python
import asyncio
from cognee import add, cognify, search

async def main():
    await add("data")
    await cognify()
    results = await search("query")

asyncio.run(main())
```

### Pipeline Task Pattern
Tasks follow a consistent pattern with `run()` methods that accept and return data:
```python
class MyTask(Task):
    async def run(self, data):
        # Process data
        return processed_data
```

### Error Handling
The system uses custom exceptions in `cognee/exceptions/` and module-specific exceptions.
Pipelines handle errors gracefully and log to structured logging system.

## Performance Considerations

### Rate Limiting
- Embedding and LLM calls are rate-limited
- Configurable in `cognee/infrastructure/llm/rate_limiter.py`
- Automatic retry with exponential backoff

### Chunking Strategy
- Default chunk size calculated as: `min(embedding_max_tokens, llm_max_tokens // 2)`
- Typically 512-8192 tokens depending on models
- Smaller chunks provide more granular but potentially fragmented knowledge

### Database Optimization
- Use file-based DBs (SQLite, LanceDB, Kuzu) for development
- Switch to server-based DBs for production
- Graph queries can be expensive - use appropriate indexing

## Dataset Management Strategy

### Core Concepts

Cognee organizes knowledge into **datasets** - logical containers for related information:

1. **Default Dataset**: If not specified, uses `"main_dataset"`
2. **Multi-User Support**: Each user can have datasets with the same name (unique IDs generated from dataset_name + user_id)
3. **Dataset Isolation**: Each dataset maintains separate vector/graph database namespaces

### When to Use Datasets

#### Single Dataset (Simplest)
```python
# Everything goes into default dataset
await cognee.add("content")  # Uses "main_dataset"
await cognee.cognify()
```

#### Multiple Datasets (Recommended for Multi-App)
```python
# Separate datasets per application/domain
await cognee.add(netbuild_code, dataset_name="app_netbuild")
await cognee.add(value_code, dataset_name="app_value")
await cognee.add(ui_components, dataset_name="forus_ui")
```

### Dataset Best Practices

1. **One Dataset Per App**: Each application gets its own knowledge base
2. **Code + Documentation Together**: Single dataset contains both for holistic understanding
3. **Clean Rebuilds for Major Releases**: Prevent knowledge pollution from experiments
4. **Incremental Updates for Minor Changes**: Just add new/modified content

### Managing Dataset Evolution

```python
# Incremental updates (recommended for ongoing development)
await cognee.add("new_feature.py", dataset_name="my_app")
await cognee.cognify()  # Updates existing graph

# Clean rebuild (for major releases)
await cognee.prune()  # Or delete specific dataset
await cognee.add(repo_path, dataset_name="my_app_v2.0")
await cognee.cognify()

# Selective deletion (remove outdated items)
await cognee.delete(data_id="uuid", dataset_id="uuid", mode="soft")
```

## Multi-App Copilot Architecture

### Overview

Each Forus app can have its own intelligent copilot powered by Ollama + Cognee:

```
App → Ollama (with MCP) → Cognee MCP Server → App-specific Dataset
```

### Implementation Pattern

1. **Create App-Specific Dataset**:
```python
await cognee.add("/app/src", dataset_name="app_name")
await cognee.add("/app/docs", dataset_name="app_name")
await cognee.cognify(dataset_name="app_name")
```

2. **Configure App-Specific MCP Server**:
```bash
# cognee-mcp-appname.sh
export COGNEE_DATASET="app_name"
python ~/cognee/cognee-mcp/src/server.py
```

3. **Connect Ollama to App's Knowledge**:
```bash
ollmcp stdio ~/bin/cognee-mcp-appname.sh
```

### Benefits

- **Contextual Intelligence**: Each copilot understands its specific app
- **Knowledge Isolation**: Apps don't cross-pollinate knowledge
- **Scalable Architecture**: Easy to add new apps
- **Local Processing**: All inference on local hardware

For detailed implementation, see `docs/MULTI_APP_COPILOT_ARCHITECTURE.md`.

## Troubleshooting

### Common Issues
1. **Import errors**: Ensure all dependencies installed with `uv sync --all-extras`
2. **Database connection**: Check `.env` configuration and Docker containers
3. **LLM errors**: Verify API keys and rate limits
4. **Memory issues**: Adjust chunk sizes or use streaming where available

### Debug Mode
Enable detailed logging:
```python
import os
os.environ["LOG_LEVEL"] = "DEBUG"
```

Or in Docker:
```yaml
environment:
  - LOG_LEVEL=DEBUG
  - DEBUG=true
```