# Multi-App Copilot Architecture with Cognee + Ollama

## Overview

This document outlines the architecture for implementing intelligent copilots across multiple Forus applications using Cognee's knowledge graph capabilities and Ollama's local LLM inference, connected via the Model Context Protocol (MCP).

## Key Discoveries

### Ollama MCP Support

Contrary to initial assumptions, Ollama **can** use MCP servers through several community-developed solutions:

1. **ollama-mcp-bridge** - TypeScript bridge connecting Ollama to any MCP server
2. **mcp-client-for-ollama (ollmcp)** - Python TUI client with multi-server support
3. **Dolphin MCP** - Clean Python API for Ollama + MCP integration

This means Ollama can directly access Cognee's knowledge graph via MCP, enabling powerful local copilot capabilities.

## Dataset Strategy

### Core Principles

1. **One Dataset Per App/Domain** - Each application maintains its own isolated knowledge base
2. **Code + Documentation Together** - Single dataset contains both source code and documentation for holistic understanding
3. **Clean Rebuilds for Major Releases** - Prevent knowledge pollution from experimental tangents

### Dataset Organization

```
Cognee Knowledge Base
├── app_netbuild/          # NetBuild BPM platform
│   ├── Source code
│   ├── BPMN documentation
│   └── Architecture docs
├── app_value/             # Financial modeling app
│   ├── Source code
│   ├── Financial formulas
│   └── User guides
├── forus_ui_components/   # Shared UI library
│   ├── Component code
│   ├── Design system docs
│   └── Usage examples
└── main_dataset/          # Default/shared knowledge
```

### When to Create Separate Datasets

- **Different applications** requiring isolated knowledge
- **Different access permissions** between teams/users
- **Testing vs production** environments
- **Major version releases** (clean slate approach)

## Architecture Design

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     User Applications                    │
├──────────────┬──────────────┬──────────────┬───────────┤
│  NetBuild    │  Value App   │  Finance App │  New App  │
└──────┬───────┴──────┬───────┴──────┬───────┴─────┬─────┘
       │              │              │             │
┌──────▼───────┬──────▼───────┬──────▼───────┬─────▼─────┐
│ Ollama       │ Ollama       │ Ollama       │ Ollama    │
│ Instance A   │ Instance B   │ Instance C   │ Instance D│
└──────┬───────┴──────┬───────┴──────┬───────┴─────┬─────┘
       │              │              │             │
┌──────▼───────┬──────▼───────┬──────▼───────┬─────▼─────┐
│ MCP Config   │ MCP Config   │ MCP Config   │ MCP Config│
│ (netbuild)   │ (value)      │ (finance)    │ (new_app) │
└──────┬───────┴──────┬───────┴──────┬───────┴─────┬─────┘
       │              │              │             │
       └──────────────┼──────────────┼─────────────┘
                      │              │
                ┌─────▼──────────────▼─────┐
                │   Cognee MCP Server      │
                │  (Dataset-aware router)   │
                └─────────────┬─────────────┘
                              │
                ┌─────────────▼─────────────┐
                │  Cognee Knowledge Graphs  │
                │   (Multiple datasets)     │
                └───────────────────────────┘
```

### Component Details

#### 1. App-Specific MCP Launchers

Each app gets its own MCP launcher script that sets the dataset context:

```bash
#!/bin/bash
# cognee-mcp-netbuild.sh
export COGNEE_DATASET="app_netbuild"
export COGNEE_USER="netbuild_copilot"
python ~/cognee/cognee-mcp/src/server.py
```

#### 2. Modified Cognee MCP Server

The MCP server needs modifications to support dataset-specific operations:

```python
# cognee-mcp/src/server.py modifications
import os

# Get dataset from environment
dataset_name = os.environ.get("COGNEE_DATASET", "main_dataset")

@mcp.tool()
async def search(search_query: str, search_type: str) -> list:
    """Search within app-specific dataset"""
    results = await cognee.search(
        search_query,
        search_type,
        dataset_name=dataset_name
    )
    return format_results(results)

@mcp.tool()
async def add_knowledge(data: str) -> list:
    """Add knowledge to app-specific dataset"""
    await cognee.add(data, dataset_name=dataset_name)
    await cognee.cognify()
    return success_response()
```

#### 3. MCP Configuration Files

Each app maintains its MCP configuration:

```json
{
  "mcpServers": {
    "cognee-netbuild": {
      "command": "~/bin/cognee-mcp-netbuild.sh",
      "args": [],
      "env": {
        "COGNEE_DATASET": "app_netbuild",
        "LLM_MODEL": "llama3.1:8b"
      }
    },
    "netbuild-tools": {
      "command": "~/bin/netbuild-specific-tools.sh",
      "description": "App-specific tools and utilities"
    }
  }
}
```

#### 4. Ollama Integration

Ollama connects to the appropriate MCP server:

```python
# In app backend
from ollmcp import OllamaMCPClient

class AppCopilot:
    def __init__(self, app_name: str):
        self.app_name = app_name
        self.mcp_config = f"{app_name}-mcp-config.json"
        self.client = OllamaMCPClient(config=self.mcp_config)
    
    async def query(self, user_query: str):
        # Ollama uses MCP to access app-specific knowledge
        response = await self.client.chat(
            model="llama3.1:8b",
            messages=[{"role": "user", "content": user_query}],
            tools=["cognee-search", "cognee-add"]
        )
        return response
```

## Implementation Steps

### Phase 1: Cognee MCP Server Enhancement

1. **Add dataset context support** to all MCP tool functions
2. **Implement dataset validation** to ensure datasets exist
3. **Add user context** for multi-tenant support
4. **Create dataset initialization** tools for new apps

### Phase 2: Create App-Specific Infrastructure

1. **Write launcher scripts** for each Forus app:
   - `cognee-mcp-netbuild.sh`
   - `cognee-mcp-value.sh`
   - `cognee-mcp-forus-ui.sh`

2. **Create MCP configuration files**:
   - `netbuild-mcp-config.json`
   - `value-mcp-config.json`
   - `forus-ui-mcp-config.json`

### Phase 3: Build Knowledge Bases

For each application:

1. **Initialize dataset**:
```python
await cognee.add(repo_path, dataset_name="app_netbuild")
await cognee.add(docs_path, dataset_name="app_netbuild")
```

2. **Process into knowledge graph**:
```python
await cognee.cognify(dataset_name="app_netbuild")
```

3. **Verify knowledge**:
```python
results = await cognee.search(
    "What are the main components?",
    search_type="GRAPH_COMPLETION",
    dataset_name="app_netbuild"
)
```

### Phase 4: Integrate Ollama Copilots

1. **Install Ollama MCP client**:
```bash
pip install ollmcp
# or
npm install ollama-mcp-bridge
```

2. **Configure Ollama** with app-specific MCP servers

3. **Add copilot endpoints** to each app:
```python
@app.post("/copilot/query")
async def copilot_query(query: str):
    copilot = AppCopilot(app_name="netbuild")
    response = await copilot.query(query)
    return {"response": response}
```

### Phase 5: Advanced Features

1. **Dynamic context switching** for shared Ollama instances
2. **Cross-app knowledge queries** with permission controls
3. **Continuous learning** from user interactions
4. **Version management** for knowledge updates

## Configuration Examples

### NetBuild Copilot Setup

```bash
# 1. Build NetBuild knowledge base
python -c "
import asyncio
import cognee

async def setup():
    # Add NetBuild code and docs
    await cognee.add('/path/to/netbuild/src', dataset_name='app_netbuild')
    await cognee.add('/path/to/netbuild/docs', dataset_name='app_netbuild')
    
    # Process into knowledge graph
    await cognee.cognify(dataset_name='app_netbuild')
    
    print('NetBuild knowledge base ready!')

asyncio.run(setup())
"

# 2. Create launcher script
cat > ~/bin/cognee-mcp-netbuild.sh << 'EOF'
#!/bin/bash
export COGNEE_DATASET="app_netbuild"
export LLM_MODEL="llama3.1:8b"
python ~/cognee/cognee-mcp/src/server.py
EOF
chmod +x ~/bin/cognee-mcp-netbuild.sh

# 3. Start Ollama with NetBuild MCP
ollmcp stdio ~/bin/cognee-mcp-netbuild.sh
```

### Value App Copilot Setup

```bash
# Similar setup with dataset_name="app_value"
```

## Benefits

1. **Complete Isolation**: Each app's knowledge remains separate and focused
2. **Contextual Intelligence**: Copilots understand app-specific concepts and patterns
3. **Local Processing**: All inference happens on local hardware via Ollama
4. **Scalable Architecture**: Easy to add new apps without affecting existing ones
5. **Version Control**: Different apps can use different knowledge versions
6. **Tool Specialization**: Each app can have custom MCP tools beyond Cognee

## Monitoring and Maintenance

### Health Checks

```python
# Check dataset status
await cognee.cognify_status(dataset_name="app_netbuild")

# List data in dataset
await cognee.list_data(dataset_id="app_netbuild_uuid")
```

### Knowledge Updates

```python
# Incremental updates
await cognee.add("new_feature.py", dataset_name="app_netbuild")
await cognee.cognify(dataset_name="app_netbuild")

# Major release - clean rebuild
await cognee.delete(dataset_id="app_netbuild_uuid", mode="hard")
await cognee.add(repo_path, dataset_name="app_netbuild_v2")
await cognee.cognify(dataset_name="app_netbuild_v2")
```

### Performance Optimization

1. **Cache frequently accessed knowledge** at the MCP layer
2. **Use smaller, focused datasets** rather than monolithic ones
3. **Implement query result caching** for common questions
4. **Monitor Ollama resource usage** and scale accordingly

## Future Enhancements

1. **Cross-dataset queries** with permission controls
2. **Automatic knowledge updates** from git commits
3. **User feedback loop** for knowledge improvement
4. **Multi-modal support** for diagrams and UI mockups
5. **Distributed Ollama instances** for load balancing

## Conclusion

This architecture provides a robust foundation for intelligent, context-aware copilots across the Forus ecosystem. By combining Cognee's knowledge graph capabilities with Ollama's local LLM inference through MCP, each application can have its own specialized AI assistant that truly understands the codebase and documentation.

The key insight is that Ollama's MCP support enables direct access to Cognee's knowledge graphs, making it possible to build powerful copilots that run entirely on local infrastructure while maintaining the intelligence and context-awareness typically associated with cloud-based solutions.