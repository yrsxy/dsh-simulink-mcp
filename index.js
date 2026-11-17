/**
 * Host half of the Simulink bundle.
 *
 * Three jobs:
 *  1. Ship the MCP runtime (Go server + MATLAB tool sources + tool manifest)
 *     inside the package and mirror it to a stable location, so the
 *     configuration-only mcp-client row never depends on where this package
 *     was checked out.
 *  2. Install the bundled Simulink skills into the Harness skill directory.
 *  3. Serve the settings panel's HTTP endpoints, which call the already
 *     running `mcp__simulink__*` tools instead of opening a second MATLAB
 *     connection.
 */
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { execFile } from 'node:child_process'
import { homedir, tmpdir } from 'node:os'
import { dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const dshHome = process.env.DSH_HOME ?? join(homedir(), '.dsh')

/** Stable runtime location the patch points at ($DSH_HOME is per machine). */
export const runtimeDir = join(dshHome, 'simulink-mcp', 'runtime')
const skillsTarget = join(dshHome, 'skills')
const routePath = '/plugin-simulink'
const settingsFile = join(dshHome, 'simulink-mcp', 'settings.json')

/**
 * Whether a MATLAB desktop process is already running.
 *
 * Used to decide if a panel read may attach to an existing session: attaching
 * is harmless, but a tool call with no MATLAB up would start one, and the panel
 * must never start MATLAB just because it was opened.
 */
function matlabProcessRunning() {
  // The offline panel test runs on a machine where MATLAB may well be open;
  // let it pin the answer so the no-launch assertions stay deterministic.
  if (process.env.DSH_SIMULINK_TEST_MATLAB === 'absent') return Promise.resolve(false)
  if (process.env.DSH_SIMULINK_TEST_MATLAB === 'present') return Promise.resolve(true)
  // Windows names the process MATLAB.exe; the macOS bundle runs MATLAB_maca64,
  // and pgrep is what exists everywhere else, so this probe is not Windows only.
  const [command, args] = process.platform === 'win32'
    ? ['tasklist', ['/FI', 'IMAGENAME eq MATLAB.exe', '/NH']]
    : ['pgrep', ['-f', 'MATLAB_maca64|MATLAB_R[0-9]{4}[ab]\.app/Contents/MacOS/MATLAB']]
  return new Promise((resolve) => {
    execFile(command, args, { windowsHide: true, timeout: 8_000 }, (error, stdout) => {
      const text = stdout ?? ''
      resolve(error === null && (process.platform === 'win32' ? /MATLAB\.exe/i.test(text) : text.trim() !== ''))
    })
  })
}

/**
 * Panel preference: whether DSH should bring MATLAB up by itself at boot.
 * Stored next to apply.json so it survives restarts and needs no profile edit.
 */
function readSettings() {
  try {
    const raw = JSON.parse(readFileSync(settingsFile, 'utf8'))
    return { autoStartMatlab: raw?.autoStartMatlab === true }
  } catch {
    return { autoStartMatlab: false }
  }
}

function writeSettings(next) {
  mkdirSync(dirname(settingsFile), { recursive: true })
  writeFileSync(settingsFile, `${JSON.stringify(next, null, 2)}\n`)
  return next
}

function walk(dir, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) walk(full, out)
    else if (entry.isFile()) out.push(full)
  }
  return out
}

function stampOf(dir) {
  if (!existsSync(dir)) return 'missing'
  const files = walk(dir)
  const bytes = files.reduce((sum, file) => sum + statSync(file).size, 0)
  return `${files.length}:${bytes}`
}

/** Files the last syncRuntime() could not refresh because they are in use. */
let runtimeSyncNotes = []

/**
 * Mirror package/runtime to a stable path, skipping the copy when unchanged.
 *
 * The mirror is never removed wholesale: the running matlab-mcp-server keeps
 * its own .exe and the files under .logs open there, and on Windows deleting
 * those fails with EPERM — which used to abort the whole apply() (no skills,
 * no startup.m, stale panel state). Overlay file by file and tolerate locks;
 * leave the stamp unwritten while anything was skipped so a later boot retries.
 */
function syncRuntime() {
  const source = join(here, 'runtime')
  if (!existsSync(source)) throw new Error(`Simulink runtime is missing from the package: ${source}`)
  runtimeSyncNotes = []
  const stampFile = join(runtimeDir, '.stamp')
  const wanted = `${readFileSync(join(here, 'package.json'), 'utf8').match(/"version":\s*"([^"]+)"/)?.[1] ?? ''}|${stampOf(source)}`
  if (existsSync(stampFile) && readFileSync(stampFile, 'utf8') === wanted) return false
  mkdirSync(runtimeDir, { recursive: true })
  const shipped = new Set(walk(source).map((file) => relative(source, file)))
  for (const file of walk(source)) {
    const dest = join(runtimeDir, relative(source, file))
    try {
      const src = statSync(file)
      const cur = existsSync(dest) ? statSync(dest) : undefined
      if (cur !== undefined && cur.size === src.size && cur.mtimeMs === src.mtimeMs) continue
      mkdirSync(dirname(dest), { recursive: true })
      cpSync(file, dest, { force: true })
    } catch (error) {
      runtimeSyncNotes.push(`${relative(source, file)}: ${error.code ?? error.message}`)
    }
  }
  // Drop files a newer package no longer ships; keep .logs and locked entries.
  for (const file of walk(runtimeDir)) {
    const rel = relative(runtimeDir, file)
    if (rel === '.stamp' || rel.startsWith('.logs')) continue
    if (shipped.has(rel)) continue
    try { rmSync(file, { force: true }) } catch { /* in use, retry next boot */ }
  }
  if (runtimeSyncNotes.length === 0) writeFileSync(stampFile, wanted)
  return true
}

const PKG_NAME = 'dsh-simulink-mcp'
/** Names this package shipped under before it went to npm; accept both markers. */
const LEGACY_NAMES = [PKG_NAME, '@local/dsh-simulink-mcp']

/** Copy the bundled skills into the Harness skill directory.
 *
 * A bundle reload disposes the previous instance (removeSkills) around the same
 * moment the new one applies; on Windows a folder that is still being removed
 * refuses recreation with EPERM for a few hundred ms, so retry briefly instead
 * of dropping the skill from the catalog until the next restart.
 */
function installSkills() {
  const source = join(here, 'skills')
  if (!existsSync(source)) return []
  const installed = []
  for (const entry of readdirSync(source, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue
    const from = join(source, entry.name)
    if (!existsSync(join(from, 'SKILL.md'))) continue
    const to = join(skillsTarget, entry.name)
    for (let attempt = 0; ; attempt += 1) {
      try {
        mkdirSync(to, { recursive: true })
        cpSync(from, to, { recursive: true })
        writeFileSync(join(to, '.installed-by'), PKG_NAME)
        break
      } catch (error) {
        if (error.code !== 'EPERM' || attempt >= 4) throw error
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 200)
      }
    }
    installed.push(entry.name)
  }
  return installed
}

function removeSkills() {
  if (!existsSync(skillsTarget)) return
  for (const entry of readdirSync(skillsTarget, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue
    const marker = join(skillsTarget, entry.name, '.installed-by')
    const owner = existsSync(marker) ? readFileSync(marker, 'utf8').trim() : ''
    if (LEGACY_NAMES.includes(owner))
      rmSync(join(skillsTarget, entry.name), { recursive: true, force: true })
  }
}

/** Point the user's MATLAB startup.m at the mirrored tool sources. */
function ensureStartup() {
  const startup = join(homedir(), 'Documents', 'MATLAB', 'startup.m')
  const wanted = `addpath('${join(runtimeDir, 'matlab')}')`
  const current = existsSync(startup) ? readFileSync(startup, 'utf8') : ''
  if (current.includes(wanted)) return false
  mkdirSync(dirname(startup), { recursive: true })
  const next = /addpath\([^)]*simulink-mcp[^)]*matlab[^)]*\)/.test(current)
    ? current.replace(/addpath\([^)]*simulink-mcp[^)]*matlab[^)]*\)/, wanted)
    : `${current.trimEnd()}\n${wanted}\n`
  writeFileSync(startup, next)
  return true
}

export const name = 'simulink-bundle'

/** Wait for the HTTP server before apply(), which otherwise runs too early. */
export const inject = ['webServer']

export function apply(ctx) {
  const syncNote = []
  // Each step is isolated: a failure in one must not skip the others (a stale
  // runtime mirror used to swallow skill installation and startup.m updates).
  const step = (label, run) => {
    try {
      const result = run()
      if (result !== undefined) syncNote.push(result)
    } catch (error) {
      ctx.logger?.('dsh-simulink-mcp')?.warn?.(`Simulink ${label} failed: ${error.message}`)
      syncNote.push(`${label} failed: ${error.message}`)
    }
  }
  step('runtime', () => {
    const changed = syncRuntime()
    const notes = runtimeSyncNotes.length > 0 ? ` (skipped locked: ${runtimeSyncNotes.join(', ')})` : ''
    return changed ? `runtime synced${notes}` : notes === '' ? undefined : `runtime${notes}`
  })
  step('skills', () => `skills: ${installSkills().join(', ') || 'none'}`)
  step('startup.m', () => (ensureStartup() ? 'startup.m updated' : undefined))

  const server = ctx.get('webServer')
  if (server === undefined) return

  // Record what this apply() could reach; the panel route is registered below.
  try {
    let origin = null
    try { origin = server.getOrigin?.() ?? null } catch { origin = null }
    const traceFile = join(dshHome, 'simulink-mcp', 'apply.json')
    mkdirSync(dirname(traceFile), { recursive: true })
    writeFileSync(traceFile, `${JSON.stringify({
      at: new Date().toISOString(),
      packageRoot: here,
      sync: syncNote,
      origin,
      hasTools: ctx.get('tools') !== undefined,
      autoStartMatlab: readSettings().autoStartMatlab,
    }, null, 2)}\n`)
  } catch { /* a missing trace must never break the plugin */ }

  /**
   * Run one mcp__simulink__* tool and return its payload as a plain object.
   *
   * The host `tools` service has two incompatible execute() shapes: a batch of
   * calls whose `arguments` is a JSON string (0.2.2), and a single call whose
   * `arguments` is the object itself (some 0.2.1 builds). The wrong one throws
   * "tool execution arguments must be losslessly JSON-serializable", which shows
   * up in the panel as the opaque "no tool result", so pick the shape at runtime
   * and remember it instead of pinning a version.
   */
  let callShape

  /** Host results are either one materialized result or a `results` batch. */
  function firstResult(settled) {
    if (settled === null || typeof settled !== 'object') return undefined
    return settled.results?.[0] ?? settled
  }

  async function executeTool(tool, args, timeoutMs) {
    const tools = ctx.get('tools')
    if (tools === undefined) throw new Error('The tools service is unavailable')
    const shapes = callShape === 'single' ? ['single', 'batch'] : ['batch', 'single']
    const errors = []
    for (const shape of shapes) {
      try {
        const settled = shape === 'batch'
          ? await tools.execute({
            calls: [{ type: 'tool-call', id: `dsh-simulink-mcp:${tool}`, name: tool, arguments: JSON.stringify(args) }],
            signal: AbortSignal.timeout(timeoutMs),
          })
          : await tools.execute({
            callId: `dsh-simulink-mcp:${tool}`,
            rootCallId: 'dsh-simulink-mcp',
            name: tool,
            arguments: args,
            signal: AbortSignal.timeout(timeoutMs),
          })
        const first = firstResult(settled)
        if (first !== undefined && first !== null) {
          callShape = shape
          return first
        }
        errors.push(`${shape}: empty result`)
      } catch (error) {
        errors.push(`${shape}: ${error instanceof Error ? error.message : String(error)}`)
      }
    }
    throw new Error(errors.join('; '))
  }

  async function callTool(tool, args) {
    return interpret(await executeTool(tool, args, 120_000))
  }

  function interpret(first) {
    if (first === undefined) return { ok: false, error: 'no tool result' }
    if (first.isError === true || first.result?.isError === true) {
      const failure = first.isError === true ? first : first.result
      const text = textOf(failure)
      return { ok: false, error: text || failure.error?.message || 'tool failed' }
    }
    return payloadOf(first) ?? { ok: false, error: 'unrecognised tool result', raw: first }
  }

  /** Last good session snapshot, so the panel stays responsive while MATLAB boots. */
  let sessionCache = { env: null, models: null, error: null }
  /** Single-flight launch: a burst of clicks/timers shares one MATLAB boot. */
  let launchPromise = null
  let launchState = { state: 'idle', pid: null, error: null, at: null }

  const launchView = () => ({ ...launchState })

  /**
   * Bring MATLAB up through the MCP server and wait until the session answers.
   *
   * `sl_env` is the cheapest tool that forces the server to attach to a shared
   * desktop session or start one; a desktop session needs tens of seconds to
   * answer, so poll instead of reporting the first failure. Concurrent callers
   * (panel click + boot timer + status poll) share the same promise so the
   * server never races two boots.
   */
  function ensureMatlab() {
    if (launchPromise !== null) return launchPromise
    launchState = { state: 'starting', pid: null, error: null, at: new Date().toISOString() }
    launchPromise = (async () => {
      let last = { ok: false, error: 'MATLAB did not start' }
      for (let attempt = 0; attempt < 20; attempt += 1) {
        if (attempt > 0) await new Promise((resolve) => setTimeout(resolve, 3_000))
        try {
          const result = await callTool('mcp__simulink__sl_env', { detail: '' })
          if (result.ok === true) {
            launchState = { state: 'ready', pid: result.pid ?? null, error: null, at: launchState.at }
            sessionCache.env = result
            return result
          }
          last = result
        } catch (error) {
          last = { ok: false, error: error instanceof Error ? error.message : String(error) }
        }
      }
      launchState = { state: 'failed', pid: null, error: last.error ?? 'MATLAB did not start', at: launchState.at }
      return last
    })().finally(() => { launchPromise = null })
    return launchPromise
  }

  /** Small JSON request body reader for the panel's POST routes. */
  async function readJson(req) {
    const chunks = []
    for await (const chunk of req) chunks.push(chunk)
    try {
      return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')
    } catch {
      return {}
    }
  }

  /** Concatenated text blocks of any result shape, including a nested `result`. */
  function textOf(node) {
    const blocks = node?.content ?? node?.result?.content ?? []
    return blocks.filter((block) => block.type === 'text').map((block) => block.text).join('\n')
  }

  /**
   * Tools return their payload either as `value`, as JSON text blocks, or nested
   * under `result`; accept any of those and fall back to the raw node.
   */
  function payloadOf(node) {
    if (node === null || node === undefined) return undefined
    const candidates = [node.value, node.result?.value, node.data]
    for (const candidate of candidates) {
      const parsed = parsePayload(candidate)
      if (parsed !== undefined) return parsed
    }
    const text = textOf(node)
    const parsedText = parsePayload(text)
    if (parsedText !== undefined) return parsedText
    if (node.result !== undefined && typeof node.result === 'object') return node.result
    if (node.value !== undefined) return node.value
    return undefined
  }

  function parsePayload(value) {
    if (value === undefined || value === null || value === '') return undefined
    if (typeof value === 'string') {
      try { return JSON.parse(value) } catch { return { ok: true, text: value } }
    }
    if (typeof value !== 'object') return value
    // A tool may hand back `{content:[{type:'text',text:'{"ok":true,...}'}]}`.
    const text = textOf(value)
    if (text !== '') {
      const parsed = parsePayload(text)
      if (parsed !== undefined) return parsed
    }
    if (value.value !== undefined) return parsePayload(value.value)
    if (value.result !== undefined) return parsePayload(value.result)
    return value
  }

  function reply(res, status, body, type = 'application/json; charset=utf-8') {
    const payload = typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body)
    res.writeHead(status, { 'content-type': type, 'cache-control': 'no-store' })
    res.end(payload)
  }

  ctx.effect(() => server.register({
    kind: 'prefix',
    path: routePath,
    handler: async (req, res) => {
      const url = new URL(req.url ?? '/', 'http://localhost')
      // Whether or not the host strips the prefix before dispatch, dispatch on
      // the suffix so both shapes resolve to the same route.
      const known = ['/status', '/snapshot', '/act', '/debug', '/settings']
      const route = known.find((k) => url.pathname.endsWith(k)) ?? url.pathname
      try {
        if (route === '/debug') {
          // Raw result plus the shape that produced it, so a payload mismatch is
          // diagnosable live instead of by restarting with a guess.
          const first = await executeTool(
            url.searchParams.get('tool') ?? 'mcp__simulink__sl_env',
            JSON.parse(url.searchParams.get('args') ?? '{"detail":""}'),
            60_000,
          )
          reply(res, 200, { shape: callShape ?? 'unknown', result: first })
          return
        }
        if (route === '/status') {
          const settings = readSettings()
          const launch = launchView()
          // Reading the panel must never start MATLAB: every mcp__simulink__* tool
          // brings a session up under `--matlab-session-mode=auto`, so merely
          // opening the settings page used to launch MATLAB. Answer from the cache
          // unless a launch is running, the session is known ready, or the user
          // explicitly asked to probe (`?probe=1`, the Refresh button).
          // An explicit probe (Refresh) always runs. A plain panel read only
          // probes when a MATLAB process is already alive, so attaching is safe
          // and opening the page still never brings a session up by itself.
          const probe = url.searchParams.get('probe') === '1'
            || (launch.state !== 'ready' && await matlabProcessRunning())
          if (launch.state === 'starting') {
            reply(res, 200, {
              sync: syncNote,
              settings,
              launch,
              env: sessionCache.env ?? { ok: false, error: 'MATLAB is starting' },
              models: sessionCache.models ?? { ok: true, models: [], libraries: [] },
              error: sessionCache.error ?? { ok: true, hasError: false },
            })
            return
          }
          // No session yet and no explicit probe: answer from the cache, never
          // touch a tool (touching one would start MATLAB behind the panel).
          if (launch.state !== 'ready' && !probe) {
            reply(res, 200, {
              sync: syncNote,
              settings,
              launch,
              env: sessionCache.env ?? { ok: false, error: 'MATLAB is not connected' },
              models: sessionCache.models ?? { ok: true, models: [], libraries: [] },
              error: sessionCache.error ?? { ok: true, hasError: false },
            })
            return
          }
          if (launch.state === 'ready' && !probe && sessionCache.env !== null) {
            reply(res, 200, { sync: syncNote, settings, launch, ...sessionCache })
            return
          }
          const [env, models, error] = await Promise.all([
            callTool('mcp__simulink__sl_env', { detail: '' }),
            callTool('mcp__simulink__sl_list_models', { pattern: '' }),
            callTool('mcp__simulink__sl_last_error', { clear_flag: false }),
          ])
          if (env.ok === true) sessionCache = { env, models, error }
          if (env.ok === true && launchState.state !== 'ready') {
            launchState = { state: 'ready', pid: env.pid ?? null, error: null, at: new Date().toISOString() }
          } else if (env.ok !== true && launchState.state === 'ready') {
            // The session we had is gone; never report a stale connection.
            launchState = { state: 'failed', pid: null, error: env.error ?? 'MATLAB is not reachable', at: new Date().toISOString() }
            sessionCache = { env: null, models: null, error: null }
          }
          reply(res, 200, { sync: syncNote, settings, launch: launchView(), env, models, error })
          return
        }
        if (route === '/settings') {
          if (req.method === 'POST') {
            const body = await readJson(req)
            const next = writeSettings({ autoStartMatlab: body.autoStartMatlab === true })
            // Enabling the toggle starts MATLAB in the background; the reply must
            // not wait for a desktop session that needs tens of seconds. Disabling
            // only stops future auto-starts and leaves a running session alone.
            if (next.autoStartMatlab) void ensureMatlab().catch(() => {})
            reply(res, 200, { settings: next, launch: launchView() })
            return
          }
          reply(res, 200, { settings: readSettings(), launch: launchView() })
          return
        }
        if (route === '/snapshot') {
          const model = url.searchParams.get('model') ?? ''
          const outPath = join(tmpdir(), `dsh-simulink-${model.replace(/[^\w-]/g, '_')}.png`)
          const result = await callTool('mcp__simulink__sl_snapshot', { model, out_path: outPath, dpi: 150 })
          if (result.ok === false || !existsSync(outPath)) {
            reply(res, 502, { ok: false, error: result.error ?? 'snapshot not written', result })
            return
          }
          reply(res, 200, readFileSync(outPath), 'image/png')
          return
        }
        if (route === '/act' && req.method === 'POST') {
          const body = await readJson(req)
          if (body.action === 'start') {
            // Kick the boot off and return at once; the panel polls /status.
            void ensureMatlab().catch(() => {})
            reply(res, 200, { ok: true, launch: launchView() })
            return
          }
          const map = {
            open: ['mcp__simulink__sl_open', { path: body.path ?? '' }],
            show: ['mcp__simulink__sl_show', { model: body.model ?? '' }],
            env: ['mcp__simulink__sl_env', { detail: 'full' }],
          }
          const call = map[body.action]
          if (call === undefined) {
            reply(res, 400, { ok: false, error: `unknown action: ${body.action}` })
            return
          }
          reply(res, 200, await callTool(call[0], call[1]))
          return
        }
        reply(res, 404, { ok: false, error: 'not found' })
      } catch (error) {
        reply(res, 500, { ok: false, error: error instanceof Error ? error.message : String(error) })
      }
    },
  }))

  // Auto-start MATLAB once the MCP row is connected: the panel's toggle
  // persists the preference and this timer honours it on every DSH boot.
  if (readSettings().autoStartMatlab) {
    const timer = setTimeout(() => {
      void ensureMatlab().then((result) => {
        ctx.logger?.('dsh-simulink-mcp')?.info?.(
          result.ok === true ? `MATLAB auto-started (pid ${result.pid})` : `MATLAB auto-start failed: ${result.error}`,
        )
      })
    }, 5_000)
    ctx.effect(() => () => clearTimeout(timer))
  }

  ctx.effect(() => () => removeSkills())
}
