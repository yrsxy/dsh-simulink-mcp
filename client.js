/**
 * Client half: the Simulink settings page.
 *
 * Reads the Host endpoints served by index.js. Everything the page shows comes
 * from the running `mcp__simulink__*` tools, so the page reports the same
 * session the agent uses instead of opening a second MATLAB connection.
 */
window.__ModuleLoader__.load({
  id: '@local/dsh-simulink-mcp',
  factory(require) {
    const React = require('react')

    const DICT = {
      en: {
        title: 'Simulink',
        subtitle: 'MATLAB session, loaded models, and model snapshots',
        refresh: 'Refresh',
        connected: 'MATLAB connected',
        disconnected: 'MATLAB not reachable',
        desktop: 'Desktop session',
        version: 'MATLAB version',
        pid: 'Process',
        toolboxes: 'Toolboxes',
        folder: 'Working folder',
        models: 'Loaded models',
        noModels: 'No model is loaded in this session.',
        open: 'Open',
        snapshot: 'Snapshot',
        snapshotHint: 'Open a model first, then export its diagram.',
        lastError: 'Last MATLAB error',
        noError: 'None',
        loading: 'Reading MATLAB session…',
        sync: 'Runtime',
        startup: 'Startup',
        autoStart: 'Open MATLAB automatically',
        autoStartHint: 'While on, DSH opens MATLAB as soon as it starts. Switch it off when you do not need MATLAB and no session will be started.',
        startNow: 'Start MATLAB now',
        starting: 'Starting MATLAB…',
        startingHint: 'A first desktop launch can take 1–3 minutes while MATLAB boots; this panel refreshes by itself.',
        refreshHint: 'Refresh asks the host for a live probe. If MATLAB is not running, that probe starts it.',
        openHint: 'Opening this page does not start MATLAB. Turn the switch on, press "Start MATLAB now", or press Refresh.',
        on: 'On',
        off: 'Off',
        launchFailed: 'Start failed',
      },
      'zh-CN': {
        title: 'Simulink',
        subtitle: 'MATLAB 会话、已加载模型与模型结构图',
        refresh: '刷新',
        connected: '已连接 MATLAB',
        disconnected: '未连上 MATLAB',
        desktop: '桌面会话',
        version: 'MATLAB 版本',
        pid: '进程号',
        toolboxes: '工具箱',
        folder: '工作目录',
        models: '已加载模型',
        noModels: '当前会话没有加载任何模型。',
        open: '打开',
        snapshot: '结构图',
        snapshotHint: '先打开一个模型，再导出结构图。',
        lastError: '最近的 MATLAB 错误',
        noError: '无',
        loading: '正在读取 MATLAB 会话…',
        sync: '运行时',
        startup: '启动',
        autoStart: '自动打开 MATLAB',
        autoStartHint: '开启后，DSH 启动时会自动打开 MATLAB；不需要时关掉即可，不会再自动启动。',
        startNow: '立即启动 MATLAB',
        starting: '正在启动 MATLAB…',
        startingHint: '首次启动 MATLAB 桌面可能需要 1–3 分钟，面板会自动刷新，请稍候。',
        refreshHint: '刷新会让宿主做一次实时探测；如果 MATLAB 没在运行，这次探测会把它启动。',
        openHint: '打开本页不会启动 MATLAB。只有开启上面的开关、点「立即启动 MATLAB」或点「刷新」才会启动。',
        on: '已开启',
        off: '已关闭',
        launchFailed: '启动失败',
      },
    }

    const styles = {
      page: { display: 'flex', flexDirection: 'column', gap: 20, padding: '4px 2px 32px', maxWidth: 880 },
      headerRow: { display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 16 },
      h1: { fontSize: 20, fontWeight: 600, margin: 0, color: 'var(--dsw-alias-label-primary)' },
      sub: { fontSize: 13, margin: '6px 0 0', color: 'var(--dsw-alias-label-secondary)' },
      button: {
        font: 'inherit', fontSize: 13, padding: '6px 12px', cursor: 'pointer',
        color: 'var(--dsw-alias-label-primary)', background: 'var(--dsw-alias-bg-layer-2)',
        border: '1px solid var(--dsw-alias-border-l1)', borderRadius: 'var(--dsw-radius-md)',
      },
      card: {
        background: 'var(--dsw-alias-bg-layer-1)', border: '1px solid var(--dsw-alias-border-l1)',
        borderRadius: 'var(--dsw-radius-lg)', padding: 16,
      },
      badge: (ok) => ({
        display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 500,
        color: ok ? 'var(--dsw-alias-state-success-primary)' : 'var(--dsw-alias-state-error-primary)',
      }),
      dot: (ok) => ({
        width: 8, height: 8, borderRadius: 4,
        background: ok ? 'var(--dsw-alias-state-success-primary)' : 'var(--dsw-alias-state-error-primary)',
      }),
      grid: { display: 'grid', gridTemplateColumns: 'auto 1fr', gap: '8px 16px', marginTop: 14, fontSize: 13 },
      key: { color: 'var(--dsw-alias-label-secondary)' },
      val: { color: 'var(--dsw-alias-label-primary)', wordBreak: 'break-all' },
      sectionTitle: { fontSize: 14, fontWeight: 600, margin: '0 0 10px', color: 'var(--dsw-alias-label-primary)' },
      row: {
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
        padding: '8px 0', borderTop: '1px solid var(--dsw-alias-border-l1)',
      },
      mono: { fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', fontSize: 12 },
      err: { ...({}), fontSize: 12, color: 'var(--dsw-alias-state-error-primary)', whiteSpace: 'pre-wrap', margin: 0 },
      img: { width: '100%', marginTop: 12, borderRadius: 'var(--dsw-radius-md)', border: '1px solid var(--dsw-alias-border-l1)' },
      hint: { fontSize: 12, margin: '4px 0 0', color: 'var(--dsw-alias-label-secondary)', lineHeight: 1.5 },
      switchTrack: (on) => ({
        position: 'relative', flex: '0 0 auto', width: 44, height: 24, borderRadius: 12,
        cursor: 'pointer', transition: 'background 0.15s', border: '1px solid var(--dsw-alias-border-l1)',
        // Hard fallbacks: a token miss must not render the "on" state as gray.
        background: on ? 'var(--dsw-alias-state-success-primary, #22c55e)' : 'var(--dsw-alias-bg-layer-2, #4b5563)',
        opacity: on ? 1 : 0.85,
      }),
      switchKnob: (on) => ({
        position: 'absolute', top: 2, left: on ? 22 : 2, width: 18, height: 18, borderRadius: 9,
        background: '#fff', transition: 'left 0.15s', boxShadow: '0 1px 2px rgba(0,0,0,0.35)',
      }),
    }

    function Panel() {
      const [state, setState] = React.useState({ phase: 'loading' })
      const [shot, setShot] = React.useState(null)
      const [busy, setBusy] = React.useState(false)
      const [polling, setPolling] = React.useState(false)
      const mounted = React.useRef(true)
      const pollingRef = React.useRef(false)
      React.useEffect(() => () => { mounted.current = false }, [])
      const locale = DICT[window.navigator?.language?.startsWith('zh') ? 'zh-CN' : 'en']
      const t = (key) => locale[key] ?? key

      /**
       * A tool payload may arrive wrapped as {content:[{type:'text',text}]} or
       * nested under `result`; unwrap it so the panel reads plain JSON.
       */
      const pick = (node) => {
        if (node === null || node === undefined) return undefined
        if (typeof node === 'object' && Array.isArray(node.content)) {
          const text = node.content
            .filter((block) => block !== null && block.type === 'text')
            .map((block) => block.text)
            .join('\n')
          if (text !== '') {
            try { return JSON.parse(text) } catch { return { ok: true, text } }
          }
        }
        if (node.value !== undefined) return pick(node.value)
        if (node.result !== undefined) return pick(node.result)
        return node
      }

      /**
       * One /status read. Every poll is cache-busted and marked no-store so a
       * cached body (from before the settings field existed) can never leave
       * the switch showing the opposite of the persisted preference.
       */
      async function readStatus(probe = false) {
        const suffix = probe ? '&probe=1' : ''
        const response = await fetch(`/plugin-simulink/status?t=${Date.now()}${suffix}`, { cache: 'no-store' })
        const raw = await response.json()
        return {
          sync: raw.sync,
          settings: raw.settings ?? { autoStartMatlab: false },
          launch: raw.launch ?? { state: 'idle' },
          env: pick(raw.env),
          models: pick(raw.models),
          error: pick(raw.error),
        }
      }

      const load = React.useCallback(async (probe = false) => {
        setBusy(true)
        try {
          const body = await readStatus(probe)
          if (mounted.current) setState({ phase: 'ready', body })
        } catch (error) {
          if (mounted.current) setState({ phase: 'failed', error: String(error) })
        } finally {
          if (mounted.current) setBusy(false)
        }
      }, [])

      /**
       * Follow a background MATLAB boot. The host answers /status from its last
       * snapshot while the launch is in flight, so polling is cheap and the
       * switch never has to wait for the desktop session.
       */
      const poll = React.useCallback(async () => {
        if (pollingRef.current) return
        pollingRef.current = true
        setPolling(true)
        try {
          for (let attempt = 0; attempt < 150; attempt += 1) {
            await new Promise((resolve) => setTimeout(resolve, 2_000))
            if (!mounted.current) return
            try {
              const body = await readStatus()
              if (!mounted.current) return
              setState({ phase: 'ready', body })
              if (body.launch.state !== 'starting') return
            } catch { /* transient while the host is busy */ }
          }
        } finally {
          pollingRef.current = false
          if (mounted.current) setPolling(false)
        }
      }, [])

      React.useEffect(() => { void load() }, [load])
      // A page reload during a boot must resume following it.
      const launchPhase = state.body?.launch?.state
      React.useEffect(() => {
        if (launchPhase === 'starting') void poll()
      }, [launchPhase, poll])

      const env = state.body?.env ?? {}
      const ok = state.phase === 'ready' && env.ok === true
      const autoStart = state.body?.settings?.autoStartMatlab === true
      const launch = state.body?.launch ?? { state: 'idle' }
      const starting = launch.state === 'starting' || polling
      const models = state.body?.models?.models ?? []
      const lastError = state.body?.error?.message ?? state.body?.error?.error

      async function openModel(model) {
        setBusy(true)
        try {
          await fetch('/plugin-simulink/act', {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            cache: 'no-store',
            body: JSON.stringify({ action: 'show', model }),
          })
          setShot(`/plugin-simulink/snapshot?model=${encodeURIComponent(model)}&t=${Date.now()}`)
          await load()
        } finally {
          if (mounted.current) setBusy(false)
        }
      }

      /** Persist the preference; enabling also kicks a background MATLAB boot. */
      async function toggleAutoStart(next) {
        // Optimistic: the switch must move on click, not after a slow boot.
        setState((prev) => ({
          phase: 'ready',
          body: { ...(prev.body ?? {}), settings: { autoStartMatlab: next } },
        }))
        if (next) setPolling(true)
        try {
          const response = await fetch('/plugin-simulink/settings', {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            cache: 'no-store',
            body: JSON.stringify({ autoStartMatlab: next }),
          })
          const raw = await response.json()
          if (!mounted.current) return
          setState((prev) => ({
            phase: 'ready',
            body: {
              ...(prev.body ?? {}),
              settings: raw.settings ?? { autoStartMatlab: next },
              launch: raw.launch ?? prev.body?.launch,
            },
          }))
          if (next) void poll()
          else await load()
        } catch (error) {
          if (mounted.current) setState((prev) => ({ ...prev, phase: 'failed', error: `settings update failed: ${String(error)}` }))
        }
      }

      async function startNow() {
        setBusy(true)
        try {
          const response = await fetch('/plugin-simulink/act', {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            cache: 'no-store',
            body: JSON.stringify({ action: 'start' }),
          })
          const raw = await response.json().catch(() => ({}))
          if (mounted.current && raw.launch !== undefined) {
            setState((prev) => ({ phase: 'ready', body: { ...(prev.body ?? {}), launch: raw.launch } }))
          }
          void poll()
        } finally {
          if (mounted.current) setBusy(false)
        }
      }

      return React.createElement('div', { style: styles.page },
        React.createElement('div', { style: styles.headerRow },
          React.createElement('div', null,
            React.createElement('h1', { style: styles.h1 }, t('title')),
            React.createElement('p', { style: styles.sub }, t('subtitle'))),
          React.createElement('button', { style: styles.button, title: t('refreshHint'), onClick: () => void load(true), disabled: busy }, t('refresh'))),

        React.createElement('div', { style: styles.card },
          React.createElement('h2', { style: styles.sectionTitle }, t('startup')),
          React.createElement('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16 } },
            React.createElement('div', null,
              React.createElement('div', { style: styles.val }, t('autoStart')),
              React.createElement('p', { style: styles.hint }, t('autoStartHint'))),
            React.createElement('div', { style: { display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 } },
              React.createElement('div', {
                role: 'switch',
                'aria-checked': autoStart,
                tabIndex: 0,
                title: t('autoStart'),
                style: styles.switchTrack(autoStart),
                onClick: () => { if (!busy) void toggleAutoStart(!autoStart) },
              }, React.createElement('span', { style: styles.switchKnob(autoStart) })),
              // A text state next to the switch, so an unresolved CSS token can
              // never leave the user guessing whether the preference is on.
              React.createElement('span', { style: { ...styles.hint, margin: 0 } },
                starting ? t('starting') : autoStart ? t('on') : t('off')))),
          starting
            ? React.createElement('p', { style: styles.hint }, t('startingHint'))
            : launch.state === 'failed'
              ? React.createElement('p', { style: styles.err }, `${t('launchFailed')}: ${launch.error ?? ''}`)
              : null,
          ok || state.phase !== 'ready'
            ? null
            : React.createElement('div', { style: { marginTop: 14 } },
                React.createElement('p', { style: styles.hint }, t('openHint')),
                React.createElement('button', { style: styles.button, disabled: busy || starting, onClick: startNow },
                  starting ? t('starting') : t('startNow')))),

        React.createElement('div', { style: styles.card },
          React.createElement('div', { style: styles.badge(ok) },
            React.createElement('span', { style: styles.dot(ok) }),
            state.phase === 'loading' ? t('loading') : starting ? t('starting') : ok ? t('connected') : t('disconnected')),
          state.phase === 'ready'
            ? React.createElement('div', { style: styles.grid },
                React.createElement('span', { style: styles.key }, t('version')),
                React.createElement('span', { style: styles.val }, env.matlabVersion ?? '—'),
                React.createElement('span', { style: styles.key }, t('pid')),
                React.createElement('span', { style: { ...styles.val, ...styles.mono } }, String(env.pid ?? '—')),
                React.createElement('span', { style: styles.key }, t('desktop')),
                React.createElement('span', { style: styles.val }, env.desktop ? 'yes' : 'no'),
                React.createElement('span', { style: styles.key }, t('toolboxes')),
                React.createElement('span', { style: styles.val }, String(env.toolboxCount ?? '—')),
                React.createElement('span', { style: styles.key }, t('folder')),
                React.createElement('span', { style: { ...styles.val, ...styles.mono } }, env.cwd ?? '—'),
                React.createElement('span', { style: styles.key }, t('sync')),
                React.createElement('span', { style: styles.val }, (state.body.sync ?? []).join(' · ') || 'up to date'))
            : state.phase === 'failed'
              ? React.createElement('p', { style: styles.err }, state.error)
              : null),

        React.createElement('div', { style: styles.card },
          React.createElement('h2', { style: styles.sectionTitle }, t('models')),
          models.length === 0
            ? React.createElement('p', { style: { ...styles.sub, margin: 0 } }, t('noModels'))
            : models.map((model) => React.createElement('div', { key: model, style: styles.row },
                React.createElement('span', { style: { ...styles.val, ...styles.mono } }, model),
                React.createElement('span', { style: { display: 'flex', gap: 8 } },
                  React.createElement('button', { style: styles.button, onClick: () => openModel(model), disabled: busy }, t('snapshot'))))),
          shot === null
            ? React.createElement('p', { style: { ...styles.sub, margin: '10px 0 0' } }, t('snapshotHint'))
            : React.createElement('img', { src: shot, alt: 'Simulink model diagram', style: styles.img })),

        React.createElement('div', { style: styles.card },
          React.createElement('h2', { style: styles.sectionTitle }, t('lastError')),
          React.createElement('p', { style: lastError ? styles.err : { ...styles.sub, margin: 0 } },
            lastError ?? t('noError'))))
    }

    return {
      inject: ['slots', 'locale'],
      apply(ctx) {
        ctx.locale.register('simulink', 'en', DICT.en)
        ctx.locale.register('simulink', 'zh-CN', DICT['zh-CN'])
        ctx.slots.inject('settings.section', () => ctx.slots.register({
          name: 'settings.section',
          id: 'simulink',
          order: 50,
          label: () => (ctx.locale.getLocale()?.id?.startsWith('zh') === true ? 'Simulink 建模' : 'Simulink'),
        }, Panel))
      },
    }
  },
})
