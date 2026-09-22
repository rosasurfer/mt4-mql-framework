[![Build Status](https://img.shields.io/badge/Build_status-passed-green?style=flat&logo=GitHub&color=%234cc61e)](https://github.com/rosasurfer/mt4-mql-framework/actions#)

# MT4 MQL Framework

A production-oriented application framework for **MetaTrader 4** with a strong focus on compatibility, defensive runtime behavior, and maintainable architecture.

## What this project is

This repository is **MT4-first** and targets legacy MT4 runtime semantics (`init()/start()/deinit()`) while providing higher-level framework hooks such as `onInit()`, `onTick()`, and `afterInit()`.

In short:
- It supports both historical and current MT4 eras.
- It is **not** a pure MT5/MQL5 codebase.
- It includes shared framework components for experts, indicators, scripts, and libraries.

## Supported language/runtime dialects

The project distinguishes three MQL dialect contexts:

- **MQL4.0**: legacy MQL behavior in MT4 terminals/builds `<= 509`
- **MQL4.5**: MT4-supported subset of MQL5-style language/runtime in builds `> 509`
- **MQL5**: full MT5 language/runtime definition

The framework is designed to keep MT4 behavior stable across MQL4.0 and MQL4.5 environments.

## First question from users: how to compile?

Use **`bin/mqlc`**, a Bash-based multi-version compiler wrapper that can compile all three supported dialects:

- MQL4.0
- MQL4.5
- MQL5

It supports single-file and batch/directory compilation, MetaEditor-compatible syntax, version selection/auto-detection, include handling, syntax-only checks, and configurable behavior via rc/environment.

## Repository layout (high level)

- `mql40/`: active framework and trading code
  - `include/rsf/`: core framework APIs and subsystems
  - `experts/`, `indicators/`, `scripts/`, `libraries/`
- `mql50/`: placeholder tree for MQL5-side structure (currently mostly empty)
- `bin/`: tooling, including the `mqlc` compiler script

## Major framework subsystems

### 1) Core runtime adapters

Core modules adapt MT4 lifecycle entrypoints to framework hooks and shared execution-context synchronization:

- `include/rsf/core/expert.mqh`
- `include/rsf/core/indicator.mqh`
- `include/rsf/core/script.mqh`
- `include/rsf/core/library.mqh`

### 2) Triplicated history libraries (`rsfHistory1/2/3`)

The framework includes three synchronized history libraries to work around MT4 file-handle limits per module and scale history-set operations.

### 3) `rsfMT4Expander.dll` interface

`mql40/include/rsf/MT4Expander.mqh` declares a broad native bridge for terminal integration, tester helpers, INI/config operations, file/path helpers, conversions, and window interaction.

> Full public source code of the DLL is maintained in the separate project: https://github.com/rosasurfer/mt4-expander

### 4) Defensive logging and error handling

`include/rsf/functions/log.mqh` implements structured framework logging (`LOG_DEBUG` .. `LOG_FATAL`), multi-appender routing, recursion-safe error trapping, and fail-safe fatal visibility behavior.

### 5) Three-layer configuration model

`include/rsf/functions/configuration.mqh` provides merged configuration resolution with this precedence:

`global -> terminal -> account`  (account has highest priority)

Layers:
1. Global config (`global-config.ini`)
2. Terminal config (`terminal-config.ini`)
3. Account config (`.../accounts/<company>/<account>-config.ini`)

## Contributor guidance

When changing core code:

- Preserve terminal-facing compatibility of `init()/start()/deinit()` flows.
- Preserve framework hook contracts (`onInit`, `onTick`, `onDeinit`, etc.).
- Be cautious with MT4 build-specific behavior and tester-vs-online differences.
- Treat duplicated libraries and defensive guards as intentional architecture, not accidental complexity.

## Additional documentation

- Deep architecture write-up: `CODEBASE_ANALYSIS.md`
- Tooling notes: `bin/README.md`
