(function () {
  'use strict';

  // ---- i18n ----
  const I18N = {
    en: {
      title: 'GKI Kernel Versions',
      subtitle: 'Android Generic Kernel Image — version tracking dashboard',
      light: 'Light',
      dark: 'Dark',
      loading: 'Loading kernel data…',
      errorTitle: 'Failed to load kernel data.',
      errorHint: 'Make sure <code>web/data/</code> contains the JSON files.',
      releases: 'Releases',
      first: 'First',
      latest: 'Latest',
      latestKernel: 'Latest Kernel',
      date: 'Security Patch',
      kernelVersion: 'Kernel Version',
      deprecated: 'Deprecated',
      deprecatedInfo: 'No longer receives security patch merges',
      susfsCompatInfo: 'SUSFS patches work directly after installing KSU, no extra patching needed',
      footerPre: 'Data sourced from',
      footerPost: '. Updated automatically via GitHub Actions.',
      announce: 'Announcement',
      announceClose: 'Close',
      announceDismiss: 'Don\u2019t show today',
      modalTitle: 'GitHub Action Parameters',
      modalAndroid: 'Android Version',
      modalKernel: 'Kernel Version',
      modalSublevel: 'Sublevel',
      modalPatch: 'Security Patch Level',
      modalSectionSource: 'Source Code',
      modalRepoInit: 'Repo Init',
      modalSectionSusfs: 'SUSFS Patch',
      modalSusfsClone: 'Clone',
      copy: 'Copy',
      copied: 'Copied',
      tcTitle: 'Time Converter',
      tcDate: 'Date',
      tcTime: 'Time (UTC)',
      tcToast: 'Copied to clipboard',
      langSwitch: '中文',
      searchPlaceholder: 'Search date or kernel version…',
      noResults: 'No matching results',
      newBadge: 'NEW',
      susfsCompat: 'SUSFS',
    },
    zh: {
      title: 'GKI 内核版本',
      subtitle: 'Android 通用内核镜像 — 版本跟踪看板',
      light: '浅色',
      dark: '深色',
      loading: '正在加载内核数据…',
      errorTitle: '加载内核数据失败。',
      errorHint: '请确保 <code>web/data/</code> 包含 JSON 文件。',
      releases: '发布数',
      first: '起始',
      latest: '最新',
      latestKernel: '最新内核',
      date: '安全补丁日期',
      kernelVersion: '内核版本',
      deprecated: '已弃用',
      deprecatedInfo: '不再接受安全补丁的合并',
      susfsCompatInfo: '安装 KSU 后可直接使用 SUSFS 补丁，无需二次修复',
      footerPre: '数据来源于',
      footerPost: '。通过 GitHub Actions 自动更新。',
      announce: '公告',
      announceClose: '关闭',
      announceDismiss: '今日不再显示',
      modalTitle: 'GitHub Action 参数',
      modalAndroid: 'Android 版本',
      modalKernel: '内核版本',
      modalSublevel: '子版本号',
      modalPatch: '安全补丁级别',
      modalSectionSource: '源码拉取',
      modalRepoInit: 'Repo 初始化',
      modalSectionSusfs: 'SUSFS 补丁拉取',
      modalSusfsClone: '克隆',
      copy: '复制',
      copied: '已复制',
      tcTitle: '时间转换',
      tcDate: '日期',
      tcTime: '时间 (UTC)',
      tcToast: '已复制到剪贴板',
      langSwitch: 'EN',
      searchPlaceholder: '搜索日期或内核版本…',
      noResults: '无匹配结果',
      newBadge: '最新',
      susfsCompat: 'SUSFS兼容',
    },
  };

  // Language priority: localStorage > navigator.language
  const savedLang = localStorage.getItem('lang');
  const lang = savedLang || (/^zh\b/i.test(navigator.language) ? 'zh' : 'en');
  const t = I18N[lang];
  document.documentElement.lang = lang === 'zh' ? 'zh-CN' : 'en';

  const DATA_FILES = [
    { android: 'android12', kernel: '5.10', label: 'android12 / 5.10', deprecatedCutoff: '2024-08' },
    { android: 'android13', kernel: '5.15', label: 'android13 / 5.15', deprecatedCutoff: '2024-09' },
    { android: 'android14', kernel: '6.1',  label: 'android14 / 6.1',  deprecatedCutoff: '2024-09' },
    { android: 'android15', kernel: '6.6',  label: 'android15 / 6.6',  deprecatedCutoff: '' },
  ];
  var RUNTIME_CACHE_KEY = Date.now().toString(36);

  // SUSFS-compatible: sublevel >= threshold means patches from susfs4ksu work directly
  var SUSFS_COMPAT_MIN = {
    '5.10': 218,
    '5.15': 144,
    '6.1': 141,
    '6.6': 92,
  };

  function isSusfsCompat(kernelStr) {
    var parts = kernelStr.split('.');
    var major = parts[0] + '.' + parts[1];
    var min = SUSFS_COMPAT_MIN[major];
    if (min == null) return false;
    var sublevel = parseInt(parts[2], 10);
    return sublevel >= min;
  }

  function withCacheKey(url) {
    return url + (url.indexOf('?') === -1 ? '?' : '&') + 'v=' + encodeURIComponent(RUNTIME_CACHE_KEY);
  }

  async function fetchJsonFresh(url) {
    var r = await fetch(withCacheKey(url), { cache: 'no-store' });
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.json();
  }

  // ---- Apply i18n to static elements ----
  document.getElementById('headerTitle').textContent = t.title;
  document.getElementById('headerSubtitle').textContent = t.subtitle;
  document.getElementById('loadingText').textContent = t.loading;
  document.getElementById('footerPre').textContent = t.footerPre;
  document.getElementById('footerPost').textContent = t.footerPost;
  document.getElementById('tcTitle').textContent = t.tcTitle;
  document.getElementById('tcDateLabel').textContent = t.tcDate;
  document.getElementById('tcTimeLabel').textContent = t.tcTime;
  document.getElementById('tcCopy').textContent = t.copy;
  document.title = t.title;

  // ---- Language switch ----
  var langToggle = document.getElementById('langToggle');
  var langLabel = document.getElementById('langLabel');
  langLabel.textContent = t.langSwitch;

  langToggle.addEventListener('click', function () {
    var newLang = lang === 'zh' ? 'en' : 'zh';
    localStorage.setItem('lang', newLang);
    location.reload();
  });

  // ---- Theme ----
  var themeToggle = document.getElementById('themeToggle');
  var themeIcon = document.getElementById('themeIcon');
  var themeLabel = document.getElementById('themeLabel');

  function setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
    if (theme === 'dark') {
      themeIcon.textContent = '\u263D';
      themeLabel.textContent = t.light;
    } else {
      themeIcon.textContent = '\u2600';
      themeLabel.textContent = t.dark;
    }
  }

  var savedTheme = localStorage.getItem('theme') || 'dark';
  setTheme(savedTheme);

  themeToggle.addEventListener('click', function () {
    var current = document.documentElement.getAttribute('data-theme');
    setTheme(current === 'dark' ? 'light' : 'dark');
  });

  // ---- Data loading ----
  async function loadData() {
    var results = await Promise.allSettled(
      DATA_FILES.map(function (f) {
        return fetchJsonFresh('data/' + f.android + '/' + f.kernel + '.json');
      })
    );

    var datasets = [];
    for (var i = 0; i < results.length; i++) {
      if (results[i].status === 'fulfilled') {
        datasets.push({ meta: DATA_FILES[i], data: results[i].value });
      }
    }

    if (datasets.length === 0) {
      document.getElementById('content').innerHTML =
        '<div class="error"><p>' + t.errorTitle + '</p><p style="margin-top:0.5rem;color:var(--text-muted)">' + t.errorHint + '</p></div>';
      return;
    }

    renderTabs(datasets);
    renderPanels(datasets);

    // Activate first tab
    var firstTab = document.querySelector('.tab');
    if (firstTab) firstTab.click();
  }

  // ---- Render tabs ----
  function renderTabs(datasets) {
    var tabsEl = document.getElementById('tabs');
    tabsEl.innerHTML = '';
    datasets.forEach(function (ds, idx) {
      var btn = document.createElement('button');
      btn.className = 'tab';
      btn.textContent = ds.meta.label;
      btn.dataset.panel = 'panel-' + idx;
      btn.addEventListener('click', function () { activateTab(btn); });
      tabsEl.appendChild(btn);
    });
  }

  function activateTab(btn) {
    document.querySelectorAll('.tab').forEach(function (t) { t.classList.remove('active'); });
    document.querySelectorAll('.tab-panel').forEach(function (p) { p.classList.remove('active'); });
    btn.classList.add('active');
    var panel = document.getElementById(btn.dataset.panel);
    if (panel) panel.classList.add('active');
  }

  // ---- Render panels ----
  function renderPanels(datasets) {
    var content = document.getElementById('content');
    content.innerHTML = '';

    datasets.forEach(function (ds, idx) {
      var panel = document.createElement('div');
      panel.className = 'tab-panel';
      panel.id = 'panel-' + idx;
      panel.innerHTML = buildCard(ds.data, ds.meta);
      content.appendChild(panel);
    });
  }

  function buildCard(data, meta) {
    var entries = data.entries || [];
    var lts = data.lts;
    var depCutoff = data.deprecated_cutoff || data.deprecatedCutoff || meta.deprecatedCutoff || '';
    var hasDepCutoff = typeof depCutoff === 'string' && depCutoff.length > 0;
    var totalReleases = entries.length;
    var firstDate = entries.length > 0 ? entries[0].date : 'N/A';
    var lastDate = entries.length > 0 ? entries[entries.length - 1].date : 'N/A';
    var lastKernel = entries.length > 0 ? entries[entries.length - 1].kernel : 'N/A';

    var ltsHtml = '';
    if (lts) {
      var ltsSublevel = lts.split('.')[2] || '';
      ltsHtml =
        '<div class="lts-box lts-clickable" data-android="' + esc(meta.android) + '" data-kernel="' + esc(meta.kernel) + '" data-sublevel="' + esc(ltsSublevel) + '" data-patch="lts">' +
          '<span class="lts-label">LTS</span>' +
          '<span class="lts-version">' + esc(lts) + '</span>' +
        '</div>';
    }
    var depBadge = hasDepCutoff
      ? '<span class="badge badge-deprecated" title="' + esc(t.deprecatedInfo) + '">' + esc(t.deprecated) + ' \u2264 ' + esc(depCutoff) + '</span>'
      : '';

    var hasSusfs = entries.some(function (e) { return isSusfsCompat(e.kernel); });
    var susfsMinKernel = hasSusfs ? meta.kernel + '.' + SUSFS_COMPAT_MIN[meta.kernel] : '';
    var susfsBadgeHeader = hasSusfs
      ? '<a href="https://gitlab.com/simonpunk/susfs4ksu" target="_blank" rel="noopener noreferrer" class="badge badge-susfs-header" title="' + esc(t.susfsCompatInfo) + '">' + esc(t.susfsCompat) + ' \u2265 ' + esc(susfsMinKernel) + '</a>'
      : '';

    // Compact legend strip for deprecated + SUSFS badges
    var legendItems = '';
    if (hasDepCutoff) {
      legendItems += '<div class="legend-item legend-deprecated">' +
        '<span class="badge badge-deprecated">' + esc(t.deprecated) + '</span>' +
        '<span class="legend-text">' + esc(t.deprecatedInfo) + '</span>' +
      '</div>';
    }
    if (hasSusfs) {
      legendItems += '<div class="legend-item legend-susfs">' +
        '<span class="badge-susfs">' + esc(t.susfsCompat) + '</span>' +
        '<span class="legend-text">' + esc(t.susfsCompatInfo) + '</span>' +
      '</div>';
    }
    var legendHtml = legendItems ? '<div class="legend-strip">' + legendItems + '</div>' : '';

    // Two-column table, ascending order (oldest to newest)
    var mid = Math.ceil(entries.length / 2);
    var leftCol = entries.slice(0, mid);
    var rightCol = entries.slice(mid);

    function buildHalf(col, isRight) {
      var rows = '';
      col.forEach(function (entry, i) {
        var sublevel = entry.kernel.split('.')[2] || '';
        var isDeprecated = hasDepCutoff && entry.date <= depCutoff;
        var isLatest = isRight ? (i === col.length - 1) : (rightCol.length === 0 && i === col.length - 1);
        var rowClass = 'row-clickable';
        if (isDeprecated) rowClass += ' row-deprecated';
        var depBadgeInner = isDeprecated ? '<span class="badge badge-deprecated" title="' + esc(t.deprecatedInfo) + '">' + esc(t.deprecated) + '</span>' : '';
        var newBadge = isLatest ? '<span class="badge-new">' + esc(t.newBadge) + '</span>' : '';
        var susfsBadge = isSusfsCompat(entry.kernel) ? '<a href="https://gitlab.com/simonpunk/susfs4ksu" target="_blank" rel="noopener noreferrer" class="badge-susfs" title="SUSFS patches work directly" onclick="event.stopPropagation();">' + esc(t.susfsCompat) + '</a>' : '';
        var badges = depBadgeInner + susfsBadge + newBadge;
        var badgesHtml = badges ? '<span class="kv-badges">' + badges + '</span>' : '';
        rows += '<tr class="' + rowClass + '" data-android="' + esc(meta.android) + '" data-kernel="' + esc(meta.kernel) + '" data-sublevel="' + esc(sublevel) + '" data-patch="' + esc(entry.date) + '">' +
          '<td class="date-cell">' + esc(entry.date) + '</td>' +
          '<td class="kernel-version"><span class="kv-text">' + esc(entry.kernel) + '</span>' + badgesHtml + '</td>' +
        '</tr>';
      });
      return '<table>' +
        '<thead class="table-half-head"><tr><th>' + t.date + '</th><th>' + t.kernelVersion + '</th></tr></thead>' +
        '<tbody>' + rows + '</tbody>' +
      '</table>';
    }

    return '<div class="card">' +
        '<div class="card-header">' +
          '<span class="badge badge-android">' + esc(meta.android) + '</span>' +
          '<span class="badge badge-kernel">Kernel ' + esc(meta.kernel) + '</span>' +
          depBadge +
          susfsBadgeHeader +
        '</div>' +
        legendHtml +
        ltsHtml +
        '<div class="stats">' +
          '<div class="stat"><div class="stat-label">' + t.releases + '</div><div class="stat-value">' + totalReleases + '</div></div>' +
          '<div class="stat"><div class="stat-label">' + t.first + '</div><div class="stat-value">' + esc(firstDate) + '</div></div>' +
          '<div class="stat"><div class="stat-label">' + t.latest + '</div><div class="stat-value">' + esc(lastDate) + '</div></div>' +
          '<div class="stat"><div class="stat-label">' + t.latestKernel + '</div><div class="stat-value">' + esc(lastKernel) + '</div></div>' +
        '</div>' +
        '<div class="table-dual-wrapper">' +
          '<div class="table-dual-header">' +
            '<span>' + t.date + '</span>' +
            '<span>' + t.kernelVersion + '</span>' +
          '</div>' +
          '<div class="table-dual-body">' +
            '<div class="table-half">' + buildHalf(leftCol, false) + '</div>' +
            '<div class="table-half">' + buildHalf(rightCol, true) + '</div>' +
          '</div>' +
        '</div>' +
      '</div>';
  }

  function esc(str) {
    var el = document.createElement('span');
    el.textContent = str;
    return el.innerHTML;
  }

  function renderInlineMarkdown(text) {
    var html = esc(text == null ? '' : String(text));
    var codeTokens = [];

    html = html.replace(/`([^`\n]+)`/g, function (_, codeText) {
      codeTokens.push('<code>' + codeText + '</code>');
      return '\u0000CODE' + (codeTokens.length - 1) + '\u0000';
    });

    html = html.replace(/\[([^\]\n]+)\]\((https?:\/\/[^\s)]+)\)/gi, function (_, label, url) {
      return '<a href="' + url + '" target="_blank" rel="noopener noreferrer">' + label + '</a>';
    });
    html = html.replace(/\*\*([^*\n]+)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*([^*\n]+)\*/g, '<em>$1</em>');

    return html.replace(/\u0000CODE(\d+)\u0000/g, function (_, idx) {
      return codeTokens[Number(idx)] || '';
    });
  }

  function renderMarkdown(markdownText) {
    var normalized = String(markdownText == null ? '' : markdownText)
      .replace(/\r\n?/g, '\n')
      .trim();
    if (!normalized) return '';

    var blocks = normalized.split(/\n{2,}/);
    var out = [];

    blocks.forEach(function (block) {
      var lines = block.split('\n');
      var fence = block.match(/^```([a-zA-Z0-9_-]+)?\n([\s\S]*?)\n```$/);
      if (fence) {
        var langClass = fence[1] ? ' class="lang-' + fence[1].toLowerCase() + '"' : '';
        out.push('<pre><code' + langClass + '>' + esc(fence[2]) + '</code></pre>');
        return;
      }

      var heading = block.match(/^\s*(#{1,6})\s+(.+)$/);
      if (heading && lines.length === 1) {
        var level = heading[1].length;
        out.push('<h' + level + '>' + renderInlineMarkdown(heading[2]) + '</h' + level + '>');
        return;
      }

      if (lines.every(function (line) { return /^\s*[-*]\s+/.test(line); })) {
        out.push('<ul>' + lines.map(function (line) {
          return '<li>' + renderInlineMarkdown(line.replace(/^\s*[-*]\s+/, '')) + '</li>';
        }).join('') + '</ul>');
        return;
      }

      if (lines.every(function (line) { return /^\s*\d+\.\s+/.test(line); })) {
        out.push('<ol>' + lines.map(function (line) {
          return '<li>' + renderInlineMarkdown(line.replace(/^\s*\d+\.\s+/, '')) + '</li>';
        }).join('') + '</ol>');
        return;
      }

      if (lines.every(function (line) { return /^\s*>\s?/.test(line); })) {
        out.push('<blockquote>' + lines.map(function (line) {
          return renderInlineMarkdown(line.replace(/^\s*>\s?/, ''));
        }).join('<br>') + '</blockquote>');
        return;
      }

      out.push('<p>' + lines.map(renderInlineMarkdown).join('<br>') + '</p>');
    });

    return out.join('');
  }

  function normalizeAnnouncementText(value) {
    if (Array.isArray(value)) return value.join('\n');
    if (value == null) return '';
    return String(value);
  }

  function getAnnouncementText(item) {
    if (lang === 'zh') {
      return normalizeAnnouncementText(item.content_zh_md || item.content_zh || item.content_md || item.content);
    }
    return normalizeAnnouncementText(item.content_md || item.content || item.content_zh_md || item.content_zh);
  }

  // ---- Modal ----
  var modal = document.getElementById('modal');
  var modalTitle = document.getElementById('modalTitle');
  var modalBody = document.getElementById('modalBody');
  var modalClose = document.getElementById('modalClose');

  function modalRow(label, value, isCode) {
    if (isCode) {
      return '<div class="modal-row modal-row-code">' +
          '<span class="modal-label">' + label + '</span>' +
          '<div class="modal-code-wrapper">' +
            '<code class="modal-code">' + esc(value) + '</code>' +
            '<button class="modal-copy" data-copy="' + esc(value) + '">' + t.copy + '</button>' +
          '</div>' +
        '</div>';
    }
    return '<div class="modal-row">' +
        '<span class="modal-label">' + label + '</span>' +
        '<span class="modal-value-group">' +
          '<span class="modal-value">' + esc(value) + '</span>' +
          '<button class="modal-copy" data-copy="' + esc(value) + '">' + t.copy + '</button>' +
        '</span>' +
      '</div>';
  }

  function showModal(android, kernel, sublevel, patch) {
    modalTitle.textContent = t.modalTitle;

    var formattedBranch = android + '-' + kernel + '-' + patch;
    var repoInitCmd = 'repo init --depth=1 -u https://android.googlesource.com/kernel/manifest -b common-' + formattedBranch + ' --repo-rev=v2.16';

    var susfsBranch = 'gki-' + android + '-' + kernel;
    var susfsCloneCmd = 'git clone https://gitlab.com/simonpunk/susfs4ksu.git -b ' + susfsBranch;

    modalBody.innerHTML =
      modalRow(t.modalAndroid, android) +
      modalRow(t.modalKernel, kernel) +
      modalRow(t.modalSublevel, sublevel) +
      modalRow(t.modalPatch, patch) +
      '<div class="modal-section">' + esc(t.modalSectionSource) + '</div>' +
      modalRow(t.modalRepoInit, repoInitCmd, true) +
      '<div class="modal-section">' + esc(t.modalSectionSusfs) + '</div>' +
      modalRow(t.modalSusfsClone, susfsCloneCmd, true);
    modal.style.display = '';
  }

  function hideModal() {
    modal.style.display = 'none';
  }

  modalClose.addEventListener('click', hideModal);
  modal.addEventListener('click', function (e) {
    if (e.target === modal) hideModal();
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { hideModal(); hideAnnounce(); }
  });

  // ---- Toast ----
  var toastEl = document.getElementById('toast');
  var toastTimer;
  function showToast(msg) {
    clearTimeout(toastTimer);
    toastEl.textContent = msg;
    toastEl.classList.add('show');
    toastTimer = setTimeout(function () {
      toastEl.classList.remove('show');
    }, 1800);
  }

  // Copy button handler (modal + time converter)
  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
    return Promise.resolve();
  }

  document.addEventListener('click', function (e) {
    var btn = e.target.closest('.modal-copy');
    if (!btn) return;
    var text = btn.dataset.copy;
    if (!text) return;
    copyText(text).then(function () {
      btn.textContent = t.copied;
      btn.classList.add('copied');
      showToast(t.tcToast);
      setTimeout(function () {
        btn.textContent = t.copy;
        btn.classList.remove('copied');
      }, 1500);
    }).catch(function () {});
  });

  // Row click
  document.addEventListener('click', function (e) {
    // LTS box
    var ltsBox = e.target.closest('.lts-clickable');
    if (ltsBox) {
      showModal(
        ltsBox.dataset.android,
        ltsBox.dataset.kernel,
        ltsBox.dataset.sublevel,
        ltsBox.dataset.patch
      );
      return;
    }
    // Table row
    var row = e.target.closest('.row-clickable');
    if (!row) return;
    showModal(row.dataset.android, row.dataset.kernel, row.dataset.sublevel, row.dataset.patch);
  });

  // ---- Header search toggle + filter ----
  var searchToggle = document.getElementById('searchToggle');
  var searchInput = document.getElementById('searchInput');
  searchInput.placeholder = t.searchPlaceholder;

  searchToggle.addEventListener('click', function () {
    var isOpen = searchInput.classList.toggle('open');
    if (isOpen) {
      searchInput.style.display = '';
      searchInput.focus();
    } else {
      searchInput.value = '';
      searchInput.style.display = 'none';
      filterActivePanel('');
    }
  });

  searchInput.addEventListener('input', function () {
    filterActivePanel(searchInput.value);
  });

  function filterActivePanel(rawQuery) {
    var panel = document.querySelector('.tab-panel.active');
    if (!panel) return;
    var card = panel.querySelector('.card');
    if (!card) return;

    var query = rawQuery.trim().toLowerCase();
    var wrapper = card.querySelector('.table-dual-wrapper');
    var rows = wrapper.querySelectorAll('tbody tr');
    var visibleCount = 0;

    rows.forEach(function (row) {
      if (!query) { row.style.display = ''; visibleCount++; return; }
      var dateText = (row.querySelector('.date-cell') || {}).textContent || '';
      var kernelText = (row.querySelector('.kernel-version') || {}).textContent || '';
      var match = dateText.toLowerCase().indexOf(query) !== -1 || kernelText.toLowerCase().indexOf(query) !== -1;
      row.style.display = match ? '' : 'none';
      if (match) visibleCount++;
    });

    var existing = card.querySelector('.search-no-results');
    if (visibleCount === 0 && query) {
      if (!existing) {
        var msg = document.createElement('div');
        msg.className = 'search-no-results';
        msg.textContent = t.noResults;
        wrapper.parentNode.insertBefore(msg, wrapper.nextSibling);
      }
      wrapper.style.display = 'none';
    } else {
      if (existing) existing.remove();
      wrapper.style.display = '';
    }
  }

  // ---- Announcement Modal ----
  var announceModal = document.getElementById('announceModal');
  var announceModalTitle = document.getElementById('announceModalTitle');
  var announceModalBody = document.getElementById('announceModalBody');
  var announceModalClose = document.getElementById('announceModalClose');
  var announceDismissToday = document.getElementById('announceDismissToday');
  var announceCloseBtn = document.getElementById('announceClose');

  function localDateStr() {
    var d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  }

  function hideAnnounce() {
    announceModal.style.display = 'none';
  }

  function dismissAnnounceToday() {
    localStorage.setItem('announce_dismiss', localDateStr());
    hideAnnounce();
  }

  announceModalClose.addEventListener('click', hideAnnounce);
  announceCloseBtn.addEventListener('click', hideAnnounce);
  announceDismissToday.addEventListener('click', dismissAnnounceToday);
  announceModal.addEventListener('click', function (e) {
    if (e.target === announceModal) hideAnnounce();
  });

  async function loadAnnouncement() {
    try {
      var json = await fetchJsonFresh('data/announcement.json');
      var items = json.items;
      if (!items || items.length === 0) return;

      if (localStorage.getItem('announce_dismiss') === localDateStr()) return;

      announceModalTitle.textContent = t.announce;
      announceDismissToday.textContent = t.announceDismiss;
      announceCloseBtn.textContent = t.announceClose;

      var html = '';
      items.forEach(function (item) {
        var text = getAnnouncementText(item);
        var markdownHtml = renderMarkdown(text);
        if (!markdownHtml) return;

        var dateText = item.date ? esc(item.date) : '';
        html += '<article class="announce-item">' +
          '<div class="announce-text">' + markdownHtml + '</div>' +
          (dateText ? '<div class="announce-meta"><time class="announce-date" datetime="' + dateText + '">' + dateText + '</time></div>' : '') +
          '</article>';
      });
      if (!html) return;
      announceModalBody.innerHTML = html;
      announceModal.style.display = '';
    } catch (e) {
      // silently ignore
    }
  }

  // ---- Time Converter ----
  var tcDate = document.getElementById('tcDate');
  var tcTime = document.getElementById('tcTime');
  var tcResult = document.getElementById('tcResult');
  var tcCopy = document.getElementById('tcCopy');

  (function initTC() {
    var now = new Date();
    tcDate.value = now.toISOString().slice(0, 10);
    tcTime.value = now.toISOString().slice(11, 19);
    updateTC();
  })();

  function updateTC() {
    var d = tcDate.value;
    var tm = tcTime.value;
    if (!d || !tm) { tcResult.textContent = '\u2014'; tcCopy.dataset.copy = ''; return; }
    var parts = tm.split(':');
    var h = parseInt(parts[0], 10);
    var m = parseInt(parts[1], 10);
    var s = parseInt(parts[2] || '0', 10);
    var dp = d.split('-');
    var local = new Date(Date.UTC(parseInt(dp[0]), parseInt(dp[1]) - 1, parseInt(dp[2]), h, m, s));
    var days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    var months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    var pad = function (n) { return String(n).padStart(2, '0'); };
    var utcStr = days[local.getUTCDay()] + ' ' + months[local.getUTCMonth()] + ' ' + pad(local.getUTCDate()) + ' ' + pad(local.getUTCHours()) + ':' + pad(local.getUTCMinutes()) + ':' + pad(local.getUTCSeconds()) + ' UTC ' + local.getUTCFullYear();
    tcResult.textContent = utcStr;
    tcCopy.dataset.copy = utcStr;
  }

  tcDate.addEventListener('input', updateTC);
  tcTime.addEventListener('input', updateTC);

  // ---- Back to top button ----
  var backToTop = document.getElementById('backToTop');
  window.addEventListener('scroll', function () {
    if (window.scrollY > 300) {
      backToTop.classList.add('visible');
    } else {
      backToTop.classList.remove('visible');
    }
  });
  backToTop.addEventListener('click', function () {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  // ---- Init ----
  loadAnnouncement();
  loadData();
})();
