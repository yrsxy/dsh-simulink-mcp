/**
 * Launch the MathWorks MCP server for this machine.
 *
 * The mcp-client row only knows two things: run Node (this Electron app with
 * ELECTRON_RUN_AS_NODE) and run this file. Everything machine specific is
 * resolved here, so the package can be installed anywhere without editing the
 * composition:
 *   - which bundled server binary matches this platform,
 *   - where MATLAB lives (PATH, so the server can start a session),
 *   - the absolute paths of the tool manifest and log folder.
 *
 * MATLAB is looked for in this order, most explicit first: MATLAB_ROOT,
 * MATLAB_INSTALL_DIR, the MathWorks registry keys, the standard install
 * folders, then a scan of every drive for a portable copy. Whatever was
 * searched is written to .matlab-search.json next to this file, and the logs
 * repeat it, so "it cannot find MATLAB" is answerable without guessing.
 */
const { execFileSync, spawn } = require('node:child_process')
const { existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } = require('node:fs')
const { join } = require('node:path')

const here = __dirname
const platformDir = `${process.platform}-${process.arch}`
const exeName = process.platform === 'win32' ? 'matlab-mcp-server.exe' : 'matlab-mcp-server'
const binary = join(here, 'bin', platformDir, exeName)
const isWindows = process.platform === 'win32'

function hasMatlab(root) {
  if (!root) return false
  return existsSync(join(root, 'bin', isWindows ? 'matlab.exe' : 'matlab'))
}

/** Highest release first, so R2024a beats R2022b when both are installed. */
const newestFirst = (list) => [...new Set(list.filter(Boolean))].sort().reverse()

function registryRoots() {
  if (!isWindows) return []
  const roots = []
  const hives = [
    'HKLM\\SOFTWARE\\MathWorks\\MATLAB',
    'HKLM\\SOFTWARE\\WOW6432Node\\MathWorks\\MATLAB',
    'HKCU\\SOFTWARE\\MathWorks\\MATLAB',
  ]
  for (const hive of hives) {
    try {
      const out = execFileSync('reg', ['query', hive, '/s', '/v', 'MATLABROOT'], {
        encoding: 'utf8', windowsHide: true, timeout: 8000,
      })
      for (const match of out.matchAll(/MATLABROOT\s+REG_(?:SZ|EXPAND_SZ)\s+(.+)/g)) roots.push(match[1].trim())
    } catch {
      // The key simply does not exist for this hive.
    }
  }
  return newestFirst(roots)
}

function programFilesRoots() {
  if (!isWindows) {
    const apps = existsSync('/Applications') ? readdirSync('/Applications') : []
    return newestFirst(apps.filter((name) => /^MATLAB_R\d{4}[ab]\.app$/.test(name)).map((name) => join('/Applications', name)))
  }
  const roots = []
  for (const base of [process.env.ProgramFiles, process.env['ProgramFiles(x86)'], 'C:\\Program Files']) {
    if (!base) continue
    const dir = join(base, 'MATLAB')
    if (!existsSync(dir)) continue
    try {
      for (const name of readdirSync(dir)) if (/^R\d{4}[ab]$/.test(name)) roots.push(join(dir, name))
    } catch {
      // An unreadable Program Files directory is not fatal.
    }
  }
  return newestFirst(roots)
}

/** Portable installs land wherever the user unzipped them: F:\matlab, D:\MATLAB\R2022b, ... */
function driveRoots() {
  if (!isWindows) return []
  const found = []
  for (let code = 67; code <= 90; code++) {
    const drive = `${String.fromCharCode(code)}:`
    if (!existsSync(`${drive}\\`)) continue
    for (const name of ['matlab', 'MATLAB']) {
      const dir = `${drive}\\${name}`
      if (hasMatlab(dir)) found.push(dir)
      try {
        for (const sub of readdirSync(dir)) {
          if (!/^R\d{4}[ab]$/.test(sub)) continue
          const nested = `${dir}\\${sub}`
          if (hasMatlab(nested)) found.push(nested)
        }
      } catch {
        // Not a directory we can read; skip it.
      }
    }
  }
  return found
}

/**
 * Whether a MATLAB desktop process exists right now.
 *
 * Used only to decide if stale session folders may be deleted: a folder whose
 * session died makes the server attach, wait ~30 s, fail, and retry before it
 * finally starts a new one, so a first launch can look broken for minutes.
 */
function matlabIsRunning() {
  try {
    if (isWindows) {
      const out = execFileSync('tasklist', ['/FI', 'IMAGENAME eq MATLAB.exe', '/NH'], {
        encoding: 'utf8', windowsHide: true, timeout: 8000,
      })
      return /MATLAB\.exe/i.test(out)
    }
    execFileSync('pgrep', ['-f', 'MATLAB_maca64|MATLAB_R[0-9]{4}[ab]\.app/Contents/MacOS/MATLAB'], {
      stdio: 'ignore', timeout: 8000,
    })
    return true
  } catch {
    return false
  }
}

/**
 * Delete session folders left behind by a MATLAB that is gone.
 *
 * The server treats such a folder as a live shared session and spends its whole
 * timeout attaching to a port nothing listens on. Only runs when no MATLAB
 * process exists, so a live session is never touched.
 */
function clearDeadSessions() {
  const logs = join(here, '.logs')
  if (!existsSync(logs) || matlabIsRunning()) return
  for (const name of readdirSync(logs)) {
    if (!/^(matlab-session-|\.matlab-mcp-server-)/.test(name)) continue
    try { rmSync(join(logs, name), { recursive: true, force: true }) } catch { /* in use */ }
  }
}

clearDeadSessions()

const searched = []
function pick(candidates) {
  for (const candidate of candidates) {
    if (!candidate) continue
    searched.push(candidate)
    if (hasMatlab(candidate)) return candidate
  }
  return undefined
}

const root = pick([
  process.env.MATLAB_ROOT,
  process.env.MATLAB_INSTALL_DIR,
  ...registryRoots(),
  ...programFilesRoots(),
  ...driveRoots(),
])

try {
  writeFileSync(join(here, '.matlab-search.json'), `${JSON.stringify({
    at: new Date().toISOString(),
    platform: platformDir,
    found: root ?? null,
    searched: searched.slice(0, 200),
  }, null, 2)}\n`)
} catch {
  // Diagnostics must never stop the server from starting.
}

if (root) {
  const bin = join(root, 'bin')
  const sep = isWindows ? ';' : ':'
  const extra = isWindows ? [bin, join(bin, 'win64')] : [bin]
  process.env.PATH = [...extra, process.env.PATH ?? ''].join(sep)
} else {
  console.error('[simulink-mcp] MATLAB not found. Looked in:')
  for (const path of searched.slice(0, 40)) console.error(`  ${path}`)
  console.error('[simulink-mcp] set MATLAB_ROOT (or MATLAB_INSTALL_DIR) to the MATLAB folder that contains bin/.')
}

const args = process.argv.slice(2)
const has = (prefix) => args.some((arg) => arg.startsWith(`${prefix}=`))

if (root && !has('--matlab-root')) {
  // The server rejects --matlab-root in existing-session mode.
  const mode = args.find((arg) => arg.startsWith('--matlab-session-mode='))?.split('=')[1] ?? 'auto'
  if (mode !== 'existing') args.push(`--matlab-root=${root}`)
}

if (!has('--extension-file')) args.push(`--extension-file=${join(here, 'tools', 'simulink-tools.json')}`)
if (!has('--log-folder')) {
  const logs = join(here, '.logs')
  try { mkdirSync(logs, { recursive: true }) } catch { /* logging is optional */ }
  args.push(`--log-folder=${logs}`)
}

if (!existsSync(binary)) {
  console.error(`[simulink-mcp] no server binary for ${platformDir} (looked for ${binary})`)
  process.exit(1)
}

const child = spawn(binary, args, { stdio: 'inherit', env: process.env, windowsHide: true })
child.on('error', (error) => {
  console.error('[simulink-mcp] cannot start the server:', error.message)
  process.exit(1)
})
child.on('exit', (code, signal) => process.exit(code ?? (signal ? 1 : 0)))
