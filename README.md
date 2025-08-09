```
 ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗     ██████╗ ██████╗ ██████╗ ███████╗
██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝
██║     ██║     ███████║██║   ██║██║  ██║█████╗      ██║     ██║   ██║██║  ██║█████╗  
██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝      ██║     ██║   ██║██║  ██║██╔══╝  
╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗    ╚██████╗╚██████╔╝██████╔╝███████╗
 ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝     ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
                                                                                         
██╗   ██╗███╗   ██╗██╗     ██╗███╗   ███╗██╗████████╗███████╗██████╗                   
██║   ██║████╗  ██║██║     ██║████╗ ████║██║╚══██╔══╝██╔════╝██╔══██╗                  
██║   ██║██╔██╗ ██║██║     ██║██╔████╔██║██║   ██║   █████╗  ██║  ██║                  
██║   ██║██║╚██╗██║██║     ██║██║╚██╔╝██║██║   ██║   ██╔══╝  ██║  ██║                  
╚██████╔╝██║ ╚████║███████╗██║██║ ╚═╝ ██║██║   ██║   ███████╗██████╔╝                  
 ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝╚═╝     ╚═╝╚═╝   ╚═╝   ╚══════╝╚═════╝                   
```

### 🚀 Break free from the 25,000 token limit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/krushr1/claude-code-unlimited)

## What is this?

A powerful caching and reading system that eliminates Claude Code's 25,000 token file limit. Read files with millions of tokens, process them in parallel, and cache them for instant access.

![Claude Code Unlimited Demo](images/claude-code-read.png)

```
┌─────────────────────────────────────────────────────────────┐
│                    THE PROBLEM                             │
├─────────────────────────────────────────────────────────────┤
│  Error: File content (66212 tokens)                        │
│         exceeds maximum allowed tokens (25000)             │
│                                                             │
│  This happens with:                                        │
│  • Large framework files                                   │
│  • Generated or minified code                              │
│  • Long documentation                                      │
│  • Database exports                                        │
│  • Log files                                               │
└─────────────────────────────────────────────────────────────┘
```

## ✨ The Solution

Claude Code Unlimited automatically:
- **Detects** file size before reading
- **Splits** large files into parallel chunks
- **Bypasses** token limits completely
- **Caches** in RAM for 500x faster re-reads
- **Syncs** changes in real-time with file watching
- **Persists** cache across sessions in single volume
- **Intercepts** Read tool failures automatically

## 📦 Installation

### Quick Install (Recommended)
```bash
curl -sL https://raw.githubusercontent.com/krushr1/claude-code-unlimited/main/install.sh | bash
```

### Manual Install
```bash
# Clone the repository
git clone https://github.com/krushr1/claude-code-unlimited.git
cd claude-code-unlimited

# Run installer
./install.sh
```

## Usage

### Live Cache Mode (Recommended) 🔥
Real-time file synchronization with persistent cache that survives across sessions:
```bash
# Start live cache with file watching
~/.claude/cache/cache-live.sh start

# Check cache status
~/.claude/cache/cache-live.sh status

# Force sync all files
~/.claude/cache/cache-live.sh sync

# Watch sync activity in real-time
~/.claude/cache/cache-live.sh watch-log
```

**Key Features:**
- Uses persistent volume at `/Volumes/ClaudeCache`
- Cache survives across runs (no data loss)
- Project isolation using MD5 hashes
- Automatic file change detection
- Efficient rsync-based updates

### Standard Cache Mode
Static cache for maximum speed (doesn't auto-sync changes):
```bash
# Start standard cache system
~/.claude/cache/cache-startup.sh start

# Smart read any file (auto-detects size and method)
~/.claude/cache/smart-read.sh path/to/large/file.js

# Force quantum parallel reading
~/.claude/cache/quantum-read.sh path/to/huge/file.js full
```

## 📊 Real Performance

```
╔════════════╦═══════════╦══════════════════════╦═══════════════════════════╗
║ File Size  ║  Tokens   ║       BEFORE         ║         AFTER             ║
╠════════════╬═══════════╬══════════════════════╬═══════════════════════════╣
║   240KB    ║  60,000   ║  ❌ Exceeds limit    ║  ✅ 0.8s parallel read    ║
║   1.2MB    ║  300,000  ║  ❌ Cannot read      ║  ✅ 2.1s quantum chunks   ║
║   5MB      ║ 1,250,000 ║  ❌ Impossible       ║  ✅ 4.5s full parallel    ║
╚════════════╩═══════════╩══════════════════════╩═══════════════════════════╝
```

## How It Works

### Architecture Overview
```
     ┌──────────────┐
     │  Large File  │
     └──────┬───────┘
            │
            ▼
    ┌───────────────┐
    │ Size Analysis │ ──────► Est. Tokens: 300,000
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │ Smart Router  │
    └───────┬───────┘
            │
     ┌──────┴──────┬──────────┐
     ▼             ▼           ▼
  [<20k]       [20-100k]    [>100k]
     │             │           │
     ▼             ▼           ▼
  Direct      Smart Mode   Parallel
  Read        (sections)    Chunks
     │             │           │
     └──────┬──────┴───────────┘
            ▼
    ┌───────────────┐
    │  RAM CACHE    │ ◄─── Persistent at /Volumes/ClaudeCache
    └───────────────┘
            │
            ▼
    ┌───────────────┐
    │   SUCCESS!    │
    └───────────────┘
```

### Cache Structure
```
/Volumes/ClaudeCache/           # Persistent RAM disk
├── cache/
│   └── projects/
│       ├── [project-hash-1]/   # First project
│       │   ├── files/           # Cached file contents
│       │   ├── search/          # Cached search results
│       │   └── metadata/        # Project info
│       └── [project-hash-2]/   # Second project
│           └── ...
```

## Features

- **Persistent Cache** 🔥 - Single volume that persists across sessions
- **Live Sync Mode** - Real-time cache updates with file changes
- **No Token Limits** - Read files of any size
- **Parallel Processing** - Split large files into chunks
- **RAM Caching** - 500x faster repeated access
- **Project Isolation** - Multiple projects cached separately
- **Auto-Detection** - Smart routing based on file size
- **File Watching** - fswatch (macOS) / inotify (Linux) integration
- **Zero Config** - Works immediately after install
- **Cross-Platform** - macOS, Linux support (Windows coming)

## Examples

### Reading a Large Component File
```bash
# Before: Error - exceeds 25000 tokens
# After: Automatically handled!

claude> Read the Dashboard.jsx file
# Cache system detects 85k tokens, uses quantum read, success!
```

### Working with Live Cache
```bash
# Start cache for your project
cd /your/project
~/.claude/cache/cache-live.sh start

# Edit files normally - cache auto-updates
vim src/large-component.js

# Check what's cached
~/.claude/cache/cache-live.sh status
# Live Cache Statistics:
#   RAM Disk: /Volumes/ClaudeCache (persistent)
#   Current Project: your-project
#   Project files: 247
#   File watcher: Running (PID: 12345)
```

### Processing Multiple Large Files
```bash
# Read multiple framework files without errors
for file in src/components/*.jsx; do
    ~/.claude/cache/smart-read.sh "$file" > /dev/null
done
```

## Technical Details

### Persistent Cache System
- **Single Volume**: All projects share `/Volumes/ClaudeCache`
- **Project Isolation**: Each project gets unique hash-based subdirectory
- **Efficient Updates**: Uses rsync for differential syncing
- **File Watching**: Real-time detection of file changes
- **Smart Cleanup**: Project-specific cache clearing

### Performance Optimizations
- RAM-based storage for instant access
- Parallel chunk processing for large files
- Memoized search results
- Automatic cache invalidation
- Background file watching

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Windows compatibility
- Streaming for ultra-large files (>10MB)
- Integration with Claude Code core
- Performance optimizations
- Cache compression algorithms

## License

MIT License - See [LICENSE](LICENSE) file for details

## Credits

Created by [krushr](https://github.com/krushr1) with assistance from Claude

## Issues

Found a bug? Have a suggestion? [Open an issue](https://github.com/krushr1/claude-code-unlimited/issues)

## Requirements

### macOS
- fswatch for live mode: `brew install fswatch`
- ripgrep for fast search: `brew install ripgrep`
- fd for fast find (optional): `brew install fd`

### Linux
- inotify-tools for live mode: `apt install inotify-tools`
- ripgrep for fast search: `apt install ripgrep`
- fd-find for fast find (optional): `apt install fd-find`

## Support

If this tool helps you, please star the repository! ⭐

```
─────────────────────────────────────────────────────────────────
  Breaking the barriers of AI-assisted coding, one token at a time
─────────────────────────────────────────────────────────────────
```