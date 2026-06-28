const EXACT_COMMAND = '读取记忆';
const MEMORY_PASSPHRASE = 'zhixuan-memory-bridge::2026::project-memory';
const CHANNEL_NAME = 'zhixuan.project.memory.bridge';
const STORAGE_EVENT_KEY = 'zhixuan.project.memory.bridge.event';
const STORAGE_BOOTSTRAP_PREFIX = 'zhixuan.project.memory.bridge.bootstrap.';
const STORAGE_CACHE_KEY = 'zhixuan.project.memory.bridge.cache';

const state = {
  windowId: crypto.randomUUID(),
  requestId: null,
  lastInitialInput: '',
  broadcastChannel: null,
  activeResolvers: new Map(),
  memoryPayload: null,
  decryptedSnapshot: null,
};

const elements = {
  initialInput: document.querySelector('#initial-input'),
  openWindowButton: document.querySelector('#open-window-button'),
  readLocalButton: document.querySelector('#read-local-button'),
  bridgeStatus: document.querySelector('#bridge-status'),
  windowId: document.querySelector('#window-id'),
  requestId: document.querySelector('#request-id'),
  initialCommand: document.querySelector('#initial-command'),
  matchStatus: document.querySelector('#match-status'),
  summary: document.querySelector('#snapshot-summary'),
  raw: document.querySelector('#snapshot-raw'),
  details: document.querySelector('#snapshot-details'),
  eventLog: document.querySelector('#event-log'),
};

function logEvent(message) {
  const item = document.createElement('li');
  item.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
  elements.eventLog.prepend(item);
}

function setStatus(message) {
  elements.bridgeStatus.textContent = message;
  logEvent(message);
}

function updateStatusCards() {
  elements.windowId.textContent = state.windowId;
  elements.requestId.textContent = state.requestId ?? '-';
  elements.initialCommand.textContent = state.lastInitialInput || '-';
  elements.matchStatus.textContent =
    state.lastInitialInput === EXACT_COMMAND ? '精确匹配' : '未匹配';
}

function base64ToBytes(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

async function deriveKey(salt, iterations) {
  const material = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(MEMORY_PASSPHRASE),
    'PBKDF2',
    false,
    ['deriveKey'],
  );

  return crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: base64ToBytes(salt),
      iterations,
      hash: 'SHA-256',
    },
    material,
    {
      name: 'AES-GCM',
      length: 256,
    },
    false,
    ['decrypt'],
  );
}

async function gunzipBytes(bytes) {
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'));
  const decompressed = await new Response(stream).arrayBuffer();
  return new Uint8Array(decompressed);
}

async function decryptSnapshotPayload(payloadRecord) {
  const key = await deriveKey(payloadRecord.salt, payloadRecord.pbkdf2Iterations);
  const encrypted = base64ToBytes(payloadRecord.payload);
  const tag = base64ToBytes(payloadRecord.tag);
  const merged = new Uint8Array(encrypted.length + tag.length);
  merged.set(encrypted, 0);
  merged.set(tag, encrypted.length);

  const decrypted = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: base64ToBytes(payloadRecord.iv),
    },
    key,
    merged,
  );

  const inflated = await gunzipBytes(new Uint8Array(decrypted));
  return JSON.parse(new TextDecoder().decode(inflated));
}

async function fetchMemoryPayloadFromAsset() {
  const response = await fetch('./project-memory-snapshot.enc.json', {
    cache: 'no-store',
  });

  if (!response.ok) {
    throw new Error(`无法加载项目记忆快照: ${response.status}`);
  }

  return response.json();
}

async function ensureMemoryPayload() {
  if (state.memoryPayload) {
    return state.memoryPayload;
  }

  const cached = localStorage.getItem(STORAGE_CACHE_KEY);
  if (cached) {
    state.memoryPayload = JSON.parse(cached);
    return state.memoryPayload;
  }

  const payload = await fetchMemoryPayloadFromAsset();
  localStorage.setItem(STORAGE_CACHE_KEY, JSON.stringify(payload));
  state.memoryPayload = payload;
  return payload;
}

function dispatchEnvelope(envelope) {
  if (state.broadcastChannel) {
    state.broadcastChannel.postMessage(envelope);
  }

  localStorage.setItem(
    STORAGE_EVENT_KEY,
    JSON.stringify({
      ...envelope,
      emittedAt: new Date().toISOString(),
    }),
  );
}

function resolvePendingRequest(requestId, payload, source) {
  const resolver = state.activeResolvers.get(requestId);
  if (!resolver) {
    return;
  }

  state.activeResolvers.delete(requestId);
  resolver({
    payload,
    source,
  });
}

async function renderSnapshot(snapshot, sourceLabel) {
  state.decryptedSnapshot = snapshot;
  const summaryItems = [
    ['生成时间', snapshot.generatedAt],
    ['Git HEAD', snapshot.git?.head ?? '-'],
    ['文件树节点数', String(snapshot.fileTree?.length ?? 0)],
    ['配置文件数', String(snapshot.configFiles?.length ?? 0)],
    ['文档数', String(snapshot.docs?.length ?? 0)],
    ['依赖项数', String(snapshot.dependencyInventory?.length ?? 0)],
    ['导入图节点数', String(snapshot.importGraph?.length ?? 0)],
    ['业务流定义数', String(snapshot.businessFlows?.length ?? 0)],
    ['数据来源', sourceLabel],
  ];

  elements.summary.innerHTML = '';
  for (const [label, value] of summaryItems) {
    const card = document.createElement('div');
    card.className = 'summary-card';
    card.innerHTML = `<span class="summary-label">${label}</span><strong>${value}</strong>`;
    elements.summary.appendChild(card);
  }

  elements.raw.textContent = elements.details.open
    ? JSON.stringify(snapshot, null, 2)
    : '完整快照已加载，展开后再渲染原始 JSON。';
  setStatus(`项目记忆已加载，来源：${sourceLabel}`);
}

async function loadAndRenderFromPayload(payload, sourceLabel) {
  const snapshot = await decryptSnapshotPayload(payload);
  await renderSnapshot(snapshot, sourceLabel);
}

function handleEnvelope(envelope, sourceLabel) {
  if (!envelope || envelope.windowId === state.windowId) {
    return;
  }

  if (envelope.type === 'window_bootstrapped') {
    logEvent(`捕获到新窗口启动，requestId=${envelope.requestId}，初始输入=${envelope.initialInput}`);
    return;
  }

  if (envelope.type === 'memory_request') {
    ensureMemoryPayload()
      .then((payload) => {
        dispatchEnvelope({
          type: 'memory_response',
          requestId: envelope.requestId,
          targetWindowId: envelope.windowId,
          windowId: state.windowId,
          payload,
        });
      })
      .catch((error) => {
        setStatus(`响应跨窗口请求失败：${error.message}`);
      });
    return;
  }

  if (envelope.type === 'memory_response' && envelope.targetWindowId === state.windowId) {
    resolvePendingRequest(envelope.requestId, envelope.payload, sourceLabel);
  }
}

function setupCrossWindowBridge() {
  if ('BroadcastChannel' in window) {
    state.broadcastChannel = new BroadcastChannel(CHANNEL_NAME);
    state.broadcastChannel.addEventListener('message', (event) => {
      handleEnvelope(event.data, 'BroadcastChannel');
    });
  }

  window.addEventListener('storage', (event) => {
    if (event.key !== STORAGE_EVENT_KEY || !event.newValue) {
      return;
    }
    handleEnvelope(JSON.parse(event.newValue), 'storage-event');
  });
}

function createBootstrapRecord(initialInput) {
  const requestId = crypto.randomUUID();
  const record = {
    requestId,
    initialInput,
    createdAt: new Date().toISOString(),
    origin: window.location.origin,
  };

  localStorage.setItem(
    `${STORAGE_BOOTSTRAP_PREFIX}${requestId}`,
    JSON.stringify(record),
  );

  return record;
}

function readBootstrapFromLocation() {
  const url = new URL(window.location.href);
  const requestId = url.searchParams.get('requestId');
  const initialInput = url.searchParams.get('initialInput');
  if (initialInput) {
    return {
      requestId: requestId ?? crypto.randomUUID(),
      initialInput,
    };
  }

  if (!requestId) {
    return null;
  }

  const record = localStorage.getItem(`${STORAGE_BOOTSTRAP_PREFIX}${requestId}`);
  if (!record) {
    return null;
  }

  return JSON.parse(record);
}

async function requestProjectMemory(initialInput, triggerSource) {
  state.lastInitialInput = initialInput;
  updateStatusCards();

  if (initialInput !== EXACT_COMMAND) {
    setStatus('未触发项目记忆读取：初始输入不是精确匹配的“读取记忆”');
    return;
  }

  const payload = await ensureMemoryPayload();
  const requestId = state.requestId ?? crypto.randomUUID();
  state.requestId = requestId;
  updateStatusCards();
  setStatus(`开始读取项目记忆，触发来源：${triggerSource}`);

  const pending = new Promise((resolve) => {
    state.activeResolvers.set(requestId, resolve);
  });

  dispatchEnvelope({
    type: 'memory_request',
    requestId,
    windowId: state.windowId,
  });

  const result = await Promise.race([
    pending,
    new Promise((resolve) => {
      window.setTimeout(() => {
        resolve({
          payload,
          source: `${triggerSource}-local-cache`,
        });
      }, 100);
    }),
  ]);

  await loadAndRenderFromPayload(result.payload, result.source);
}

function setupActions() {
  elements.openWindowButton.addEventListener('click', () => {
    const initialInput = elements.initialInput.value;
    const record = createBootstrapRecord(initialInput);
    const url = new URL(window.location.href);
    url.search = `?requestId=${record.requestId}`;
    window.open(url.toString(), '_blank', 'noopener,noreferrer');
    setStatus(`已打开新窗口，等待 requestId=${record.requestId} 完成启动`);
  });

  elements.readLocalButton.addEventListener('click', async () => {
    state.requestId = crypto.randomUUID();
    await requestProjectMemory(elements.initialInput.value, 'manual');
  });

  elements.details.addEventListener('toggle', () => {
    if (!elements.details.open || !state.decryptedSnapshot) {
      return;
    }
    elements.raw.textContent = JSON.stringify(state.decryptedSnapshot, null, 2);
  });
}

async function boot() {
  elements.windowId.textContent = state.windowId;
  setupCrossWindowBridge();
  setupActions();

  const bootstrap = readBootstrapFromLocation();
  if (bootstrap) {
    state.requestId = bootstrap.requestId;
    state.lastInitialInput = bootstrap.initialInput;
    updateStatusCards();

    dispatchEnvelope({
      type: 'window_bootstrapped',
      requestId: bootstrap.requestId,
      initialInput: bootstrap.initialInput,
      exactMatch: bootstrap.initialInput === EXACT_COMMAND,
      windowId: state.windowId,
    });

    await requestProjectMemory(bootstrap.initialInput, 'bootstrap');
    return;
  }

  updateStatusCards();
  setStatus('桥接器已就绪，可等待新窗口请求或手动触发读取');
}

boot().catch((error) => {
  setStatus(`桥接器启动失败：${error.message}`);
});
