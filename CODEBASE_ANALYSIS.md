# MT4 MQL4 (legacy dialect) codebase analysis

## Executive summary

This repository is an MT4-first framework that intentionally targets **MQL4 legacy runtime semantics** (the `init()/start()/deinit()` lifecycle), while exposing a cleaner internal hook API (`onInit()`, `onTick()`, `afterInit()`, etc.) through framework core wrappers.

It is **not** an MQL5-style MT4 codebase in structure or event entrypoints.

## Evidence of legacy MQL4 dialect usage

- Framework core modules define terminal entrypoints as `int init()`, `int start()`, and `int deinit()` for experts, indicators, and scripts.
  - `mql40/include/rsf/core/expert.mqh`
  - `mql40/include/rsf/core/indicator.mqh`
  - `mql40/include/rsf/core/script.mqh`
- Program modules implement framework-level handlers such as `onInit()` and `onTick()` (called by core wrappers), not direct MQL5 handlers like `OnInit()/OnTick()`.
  - Example indicator: `mql40/indicators/SuperTrend.mq4`

## Repository layout and composition

- `mql40/` contains active framework and trading code:
  - `include/` shared framework core and feature modules
  - `indicators/` custom indicators
  - `scripts/` operational scripts and utilities
  - `experts/` EAs and tools
  - `libraries/` MQ4 libraries and DLL integrations
- `mql50/` currently contains only placeholder directories (`.gitkeep`), indicating no active MQL5 code migration in this repository state.

## Architectural observations

1. **Thin runtime adapters, thick framework internals**
   - Runtime adapters map MT4 terminal lifecycle to framework hooks and shared execution context synchronization (`SyncMainContext_*` flow).

2. **Shared execution context across program types**
   - Experts, indicators, and scripts follow similar initialization/error/state paths with program-type-specific behavior.

3. **High emphasis on terminal robustness**
   - Defensive checks around MT4 quirks (missing ticks, tester/visual mode constraints, symbol availability, chart handle availability).

4. **Operational tooling built-in**
   - Extensive scripts and utility indicators for chart controls, signal operations, monitoring, and status reporting.

5. **Multi-dialect compiler tooling included**
   - `bin/mqlc` provides a Bash-based compiler wrapper that supports compiling all three project-relevant dialects: MQL4.0, MQL4.5, and MQL5, including batch/directory processing and MetaEditor-compatible syntax.

## `rsfHistory` libraries analysis (`mql40/libraries/`)

The `rsfHistory1.mq4`, `rsfHistory2.mq4`, and `rsfHistory3.mq4` modules are intentionally parallel libraries that manage MT4 `.hst` history data at two abstraction levels:

- **HistorySet** APIs: operate on a full 9-timeframe set (M1..MN1) for one symbol.
- **HistoryFile** APIs: operate on individual timeframe files.

### Why there are 3 near-identical modules

The library header comments explain a hard MT4/MQL4.0 file-handle constraint: older terminals (<=509) allow 16 open files per MQL module and newer ones (>509) allow 64. A single full set consumes many handles, so one module is not enough at scale. The 3 synchronized libraries multiply capacity (up to 21 sets in newer terminals). This is a **legacy-runtime workaround**, not accidental duplication.

### Legacy format compatibility handled explicitly

The libraries are built around MT4 history formats **400** and **401**, including version-specific behavior and guardrails documented in comments (read/write compatibility, conversion/deletion behavior across terminal builds). This is another strong signal that the code targets long MT4 build ranges, not a modernized MQL5-style-only runtime.

### Public surface area (pattern repeated across 1/2/3)

Each module exposes the same API shape (numeric suffix changes only):

- Set lifecycle and ingestion: `HistorySetX.Create/Get/Close/AddTick`
- File lifecycle and operations: `HistoryFileX.Open/Close/FindBar/ReadBar/WriteBar/UpdateBar/InsertBar/WriteLastStoredBar/WriteBufferedBar/MoveBars/AddTick`

This replicated interface allows callers to shard workloads across libraries while keeping call patterns stable.

### Internal design notes

- Maintains rich in-memory metadata for open set/file handles, symbol/timeframe mapping, header metadata, cached last-stored bars, and buffered bar updates.
- Uses both sandbox-relative and server-history file paths, with explicit validation and guard behavior.
- Includes synchronized code-maintenance guidance in comments (`HistoryFile|HistorySet[1-3]` search/replace pattern), indicating controlled triplicate maintenance.


## Functional abstraction of `mql40/include/rsf/*`

At a high level, `rsf/include` is a layered interface stack that separates runtime adaptation, domain modules, and platform bridging:

1. **Language/runtime compatibility layer**
   - `shared.mqh`, `stddefines.mqh`, `win32defines.mqh`, and `expander/*.h` define constants, aliases, error mappings, and shared structures needed across different MT4 build eras.
   - This is where differences between **MQL4.0** (legacy MQL in terminals `<=509`) and **MQL4.5** (the current MQL5-derived subset supported by MT4 terminals `>509`) are normalized for callers.

2. **Core lifecycle adapters**
   - `core/expert.mqh`, `core/indicator.mqh`, `core/script.mqh`, and `core/library.mqh` bridge terminal entrypoints (`init/start/deinit`) into framework hooks and synchronized execution context management.
   - These adapters encapsulate terminal quirks and keep user modules focused on strategy/indicator logic.

3. **Functional utilities and technical primitives**
   - `stdfunctions.mqh`, `stdlib.mqh`, and `functions/*` provide broad utility APIs: string/date parsing, chart helpers, indicator buffer management, signal configuration, and TA wrappers (`functions/ta/*`, `functions/iCustom/*`).

4. **Domain-specific modules**
   - `experts/*`: trading lifecycle, status persistence, metrics, event command handling, validation, and instance identity/state management.
   - `indicators/*`: indicator-specific initialization/deinitialization helpers.
   - `history.mqh`: imports the triplicated history libraries (`rsfHistory1/2/3.ex4`) and exposes uniform HistorySet/HistoryFile APIs.

5. **Foreign-interface boundary**
   - `MT4Expander.mqh` and `win32api.mqh` define imported DLL entrypoints that extend MT4’s native capabilities (filesystem, windowing, tester internals, context sync helpers, conversions, etc.).

### Special API area for expert functionality (`include/rsf/experts/*`)

The `experts/` subtree acts as a specialized API partition for EA-only behavior, separated from generic helper code:

- **Lifecycle orchestration**: `init.mqh`, `onTick.mqh`, `deinit.mqh` (expert-specific processing flow).
- **Trading kernel**: `trade/*` modules for position ownership checks, close/open message composition, history record updates, and trade statistics/signals.
- **Persistent status system**: `status/*` plus `status/file/*` and `status/volatile/*` for on-chart status rendering, file-backed state, and volatile toggles (metrics/open-orders/trade-history/profit-unit).
- **Operational controls and identity**: `event/onCommand.mqh` and `instance/*` for command handling, instance IDs, and test-instance restoration.
- **Validation/metrics/testing**: `validation/*`, `metric/*`, and `test/*` modules.

Architecturally, this partition avoids mixing strategy-trading concerns into the global utility layer, while still sharing common base facilities from `stdfunctions.mqh` and core context synchronization.

## MT4Expander DLL entry points (`mql40/include/rsf/MT4Expander.mqh`)

`MT4Expander.mqh` is the primary declaration surface for `rsfMT4Expander.dll`. It groups imports into explicit capability families:

> Note: The full public source code of the `rsfMT4Expander.dll` implementation is maintained in the separate project: `https://github.com/rosasurfer/mt4-expander`.

- **Terminal/process integration**: terminal paths/build/version, UI thread IDs, internal messaging, and program loading (`LoadMqlProgramA`).
- **Tester integration**: bar-model/start/end-date access and test commission helpers.
- **Chart/timeframe operations**: custom timeframe checks and virtual tick timer setup/release.
- **Configuration/INI access**: global/terminal config paths plus INI section/key CRUD and reads.
- **Date/time formatting**: GMT/local time retrieval and formatting helpers.
- **Filesystem probing**: directory/file/link/junction checks and path canonicalization helpers.
- **Math/pointer/string/conversion helpers**: NaN/Inf operations, pointer-address bridging, string and enum-to-string conversions.
- **Window property bridge**: per-window integer/double/string property CRUD via native window handles.

### Important design constraints visible in the import surface

- The header explicitly documents an array-count limit for **MQL4.0** modules and states array-parameter imports are intentionally disabled to reduce pressure on that limit; this is less relevant under **MQL4.5/MQL5**, where the specific limit is removed.
- Context synchronization entrypoints (`SyncMainContext_*`, `SyncLibContext_*`, `LeaveContext`) are present as comments in `MT4Expander.mqh`, while active import declarations for those APIs are defined in core modules and `stdfunctions.mqh`. This reflects a deliberate split between “wide capability catalog” and “runtime-critical imports used by core wrappers”.
- “Virtual no-op” declarations (`onInit`, `onTick`, `onDeinit`, etc.) document framework hook names expected to be overridden by program code, reinforcing the adapter model around legacy `init/start/deinit` terminal entrypoints.

### Positioning of language terms in this repository

- **MQL4.0**: legacy MQL dialect behavior associated with MT4 terminals/builds `<=509` (notably tighter runtime constraints like open-file limits and array/import pressure).
- **MQL4.5**: the MT4-supported subset of MQL5-style language/runtime behavior in terminals/builds `>509`.
- **MQL5**: full language/runtime definition as implemented by MT5 (broader than MT4’s MQL4.5 subset).

This repository’s framework abstractions and compatibility notes explicitly target long-lived MT4 behavior across both MQL4.0-era and MQL4.5-era terminals, rather than assuming full MQL5 semantics.

## Three-layer configuration model (`mql40/include/rsf/functions/configuration.mqh`)

Another major framework feature is a **three-layer merged configuration system** that is used by framework internals and is also available to userland code for arbitrary custom settings.

### Layers and file locations

1. **Global configuration** (all installed terminals for the current OS user)
   - File: `global-config.ini`
   - Resolved via `GetGlobalConfigPathA()` (MT4Expander entry point).

2. **Terminal configuration** (single terminal installation)
   - File: `terminal-config.ini`
   - Resolved via `GetTerminalConfigPathA()` (MT4Expander entry point).

3. **Account configuration** (single trading account)
   - File pattern: `TERMINAL_COMMON_DATAPATH\accounts\<trade-company>\<account-number>-config.ini`
   - Built by `GetAccountConfigPath()` from account company/account number and `GetTerminalCommonDataPathA()`.

### Merge precedence

Configuration values are resolved in strict order:

`global -> terminal -> account`

The effective value is therefore account-first (highest priority), implemented by reading each layer in sequence and passing the previous layer result as the next layer’s default.

### API surface and data types

The merge model is consistently implemented for multiple types:

- `GetConfigBool`, `GetConfigInt`, `GetConfigDouble`, `GetConfigString`, `GetConfigStringRaw`
- Per-layer variants (`GetGlobalConfig*`, `GetTerminalConfig*`, `GetAccountConfig*`) are also exposed.

It also exposes key-existence checks across merged and per-layer scopes (`IsConfigKey`, `IsGlobalConfigKeyA`, `IsTerminalConfigKeyA`, `IsAccountConfigKey`).

### MT4Expander-backed entry points

The configuration system relies on DLL imports from `rsfMT4Expander.dll` for path discovery and INI operations, including:

- path entry points: `GetGlobalConfigPathA`, `GetTerminalConfigPathA`
- INI/key helpers: `GetIniStringA`, `GetIniStringRawA`, `IsIniKeyA`, `IsIniSectionA`, `DeleteIniKeyA`, `DeleteIniSectionA`, `EmptyIniSectionA`

This design cleanly separates high-level merge semantics in MQL from low-level file/path handling in the DLL.


## Defensive error detection/handling analysis (`mql40/include/rsf/functions/log.mqh`)

`log.mqh` is a core resilience module, not just a message utility. It centralizes error trapping, escalation, and multi-channel telemetry in ways that match the framework’s defensive design goals.

### Error trap pipeline (`catch()`)

- `catch(caller, error, popOrder)` is the canonical runtime error trap: it normalizes the error source (`GetLastError()` or Win32-expanded error), logs as **fatal**, restores `LastError`, and optionally restores order context (`OrderPop`).
- Recursion guards are built in (`static bool isRecursion`) to prevent secondary failures in the error path from causing infinite loops.
- The function contract explicitly guarantees `GetLastError()` is reset after handling, reducing stale-error propagation between code paths.

### Layered logger with lazy config and strict defaults

- `log()` lazily resolves log configuration on first use and caches it in the execution context, with dedicated handling for super-context indicators loaded via `iCustom()`.
### Framework-defined log levels (non-native to MT4/MT5)

A key point for contributors: this framework implements a **custom structured loglevel system** that is **not provided natively by MT4 or MT5**.

- Levels used in framework code are `LOG_DEBUG`, `LOG_INFO`, `LOG_NOTICE`, `LOG_WARN`, `LOG_ERROR`, `LOG_FATAL` (plus `LOG_OFF` for filtering configuration).
- Convenience predicates (`IsLogDebug/Info/Notice/Warn/Error/Fatal`) and wrappers (`logDebug/.../logFatal`) are framework APIs layered on top of MT4 terminal primitives and DLL helpers.
- The framework also supports **per-appender thresholds** (`Log2Terminal`, `Log2Debug`, `Log2File`, `Log2Alert`, `Log2Mail`, `Log2SMS`), which goes beyond built-in MT4/MT5 logging behavior.
- `LOG_FATAL` is intentionally treated as non-disableable observability in this framework design, reinforcing fail-safe diagnostics during runtime faults.

- Configuration resolution is defensive:
  1) prefer program-specific key,
  2) fallback to generic `LogLevel`,
  3) fallback to built-in defaults (`off` in tester, `all` online),
  4) on invalid values, trigger `catch()` and force `LOG_OFF` as safe fallback.
- Appenders are ordered from faster to slower channels (terminal/debug/file before alert/mail/SMS) to reduce UI blocking risk and side effects in critical paths.

### Fatal-path guarantees and fail-safe channels

- `IsLogFatal()` is intentionally always `true`; fatal visibility is non-optional.
- Even when normal filtering would suppress output, fatal events are still forced to built-in channels (terminal/alert where configured), preserving a minimum observability baseline.
- Some appenders are clamped so they cannot be completely disabled (`log2Terminal`, `log2Alert` capped at `LOG_FATAL`)—a deliberate “never fully blind” policy.

### Re-entrancy hardening in every appender

- Each sink (`log2Terminal`, `log2Alert`, `log2Debug`, `log2File`, `log2Mail`, `log2SMS`) uses recursion guards and temporarily disables its own configured level during execution to prevent self-triggered logging loops.
- Tester-specific behavior is explicitly handled (e.g., `log2Alert()` avoids plain `Alert()/MessageBox()` semantics unsuitable for tester context and uses adapted notification flow).

### Context-aware telemetry and external integration

- Messages are enriched with symbol/timeframe/module/error descriptors and normalized line breaks for transport safety.
- File logging delegates to `AppendLogMessageA()` in `rsfMT4Expander.dll`, indicating a deliberate split between MQL orchestration and native append/storage mechanics.
- `SetLogfile()` proactively initializes logger state before delegating to `SetLogfileA()`, so file logging remains consistent across init cycles.

### Why this matters architecturally

This logging subsystem functions as a **defensive control plane** for the framework: it standardizes how runtime faults are detected, prevents error-handling recursion, enforces fatal observability, and adapts behavior between online/tester/super-context environments. That design is consistent with the broader MT4-first strategy of surviving terminal quirks across both **MQL4.0** and **MQL4.5** runtime conditions.

## Scale snapshot

`mql40` currently contains 236 files:

- experts: 3
- include: 155
- indicators: 29
- libraries: 7
- scripts: 42

## Practical implication for development

When modifying this codebase, treat it as **MQL4 legacy framework code**:

- Keep `init()/start()/deinit()` compatibility in terminal-facing code.
- Preserve framework hook conventions (`onInit`, `onTick`, `afterInit`, etc.).
- Avoid introducing MQL5-only event conventions in core flows unless explicitly designing a compatibility/migration layer.
