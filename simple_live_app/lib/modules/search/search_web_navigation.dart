/// 手机网站可能用新窗口或 SPA 路由进入房间，不能仅依赖加载回调。
class SearchWebNavigation {
  static const handlerName = 'simpleLiveSearchRoom';

  static const script = r'''
(function () {
  if (window.__simpleLiveSearchNavigation) return;
  window.__simpleLiveSearchNavigation = true;
  function report(value) {
    if (typeof value !== 'string' || !value) return;
    var bridge = window.flutter_inappwebview;
    if (!bridge || typeof bridge.callHandler !== 'function') return;
    try {
      var url = new URL(value, window.location.href);
      if (url.protocol !== 'http:' && url.protocol !== 'https:') return;
      var pending = bridge.callHandler('simpleLiveSearchRoom', url.href);
      if (pending && typeof pending.catch === 'function') pending.catch(function () {});
    } catch (_) {}
  }
  function reportLocation() { report(window.location.href); }
  document.addEventListener('click', function (event) {
    var target = event.target;
    if (target && target.nodeType !== 1) target = target.parentElement;
    var link = target && typeof target.closest === 'function' && target.closest('a[href]');
    if (link) report(link.href);
  }, true);
  // Android 的 JS 新窗口回调可能没有 URL，先记录目标再沿用网站行为。
  var originalOpen = window.open;
  window.open = function (url) {
    report(url);
    return originalOpen.apply(this, arguments);
  };
  ['pushState', 'replaceState'].forEach(function (name) {
    var original = window.history[name];
    window.history[name] = function () {
      var result = original.apply(this, arguments);
      reportLocation();
      return result;
    };
  });
  window.addEventListener('popstate', reportLocation);
  window.addEventListener('hashchange', reportLocation);
  window.addEventListener('flutterInAppWebViewPlatformReady', reportLocation);
})();
''';

  static const int desktopViewportWidth = 1280;

  /// 根据手机当前可视逻辑宽度（dp）生成桌面网页自适应视口配置。
  static String desktopViewportContent(
    double viewWidthDp, {
    int desktopWidth = desktopViewportWidth,
  }) {
    final safeViewWidth = viewWidthDp > 0 ? viewWidthDp : 390.0;
    final targetWidth =
        safeViewWidth >= desktopWidth ? safeViewWidth.round() : desktopWidth;
    final fitScale = (safeViewWidth / targetWidth).clamp(0.2, 1.0);
    final minScale = (fitScale * 0.8).clamp(0.15, fitScale);
    return 'width=$targetWidth, '
        'initial-scale=${fitScale.toStringAsFixed(4)}, '
        'minimum-scale=${minScale.toStringAsFixed(4)}, '
        'maximum-scale=3.0, '
        'user-scalable=yes';
  }

  /// 生成用于横竖屏切换或加载完成时重新自适应桌面视口的 JS 调用片段。
  static String buildDesktopViewportCall(double viewWidthDp) {
    final safeWidth = viewWidthDp > 0 ? viewWidthDp : 390.0;
    return 'if (window.__simpleLiveApplyDesktopViewport) '
        'window.__simpleLiveApplyDesktopViewport(${safeWidth.toStringAsFixed(1)});';
  }

  /// 默认 390dp 初始宽度的 Android 桌面网页辅助脚本。
  static String get androidDesktopScript => buildAndroidDesktopScript(390.0);

  /// 注入到主页面与所有登录/验证码 iframe 的桌面浏览器指纹脚本，
  /// 避免四大平台登录弹窗与风控验证码 iframe 因 UA/platform 不一致导致验证失败。
  static const String androidDesktopFingerprintScript = r'''
(function () {
  if (window.__simpleLiveDesktopFingerprint) return;
  window.__simpleLiveDesktopFingerprint = true;

  try {
    Object.defineProperty(navigator, 'platform', {
      get: function () { return 'Win32'; },
      configurable: true
    });
  } catch (_) {}

  try {
    Object.defineProperty(navigator, 'vendor', {
      get: function () { return 'Google Inc.'; },
      configurable: true
    });
  } catch (_) {}

  try {
    if (navigator.userAgentData) {
      var desktopBrands = [
        { brand: 'Google Chrome', version: '131' },
        { brand: 'Chromium', version: '131' },
        { brand: 'Not_A Brand', version: '24' }
      ];
      Object.defineProperty(navigator, 'userAgentData', {
        get: function () {
          return {
            brands: desktopBrands,
            mobile: false,
            platform: 'Windows',
            getHighEntropyValues: function () {
              return Promise.resolve({
                brands: desktopBrands,
                mobile: false,
                platform: 'Windows',
                platformVersion: '10.0.0',
                architecture: 'x86',
                bitness: '64',
                model: '',
                uaFullVersion: '131.0.0.0'
              });
            }
          };
        },
        configurable: true
      });
    }
  } catch (_) {}
})();
''';

  /// Android 桌面网页辅助脚本：
  /// 1. 伪装桌面浏览器指纹，防止平台 JS 嗅探跳转手机页或弹出拉起 APP 引导；
  /// 2. 注入并锁定自适应屏幕宽度的桌面 `<meta name="viewport">`，避免 PC 页面放大裁切，且不打断用户放大操作登录/滑块验证；
  /// 3. 禁止网页内自动播放直播流，大幅降低手机 WebView 卡顿和发热；
  /// 4. 将 target="_blank" 转为当前页导航、拦截外部 APP 协议并兜底上报 SPA 路由变化。
  static String buildAndroidDesktopScript(double initialViewWidthDp) {
    final safeInitialWidth =
        (initialViewWidthDp > 0 ? initialViewWidthDp : 390.0)
            .toStringAsFixed(1);
    return '''
$androidDesktopFingerprintScript
(function () {
  if (window.__simpleLiveAndroidDesktop) return;
  window.__simpleLiveAndroidDesktop = true;

  var DESKTOP_BASE_WIDTH = $desktopViewportWidth;
  var DESKTOP_MAX_WIDTH = 1480;
  var currentViewWidth = $safeInitialWidth;
  var lastAppliedViewWidth = 0;
  var updatingViewport = false;
  var lastAppliedContent = '';

  function ensureDesktopFitStyle() {
    try {
      if (typeof document.getElementById !== 'function' ||
          typeof document.createElement !== 'function') {
        return;
      }
      if (document.getElementById('__simpleLiveDesktopFitStyle')) return;
      var style = document.createElement('style');
      style.id = '__simpleLiveDesktopFitStyle';
      style.textContent =
        'html, body { -webkit-text-size-adjust: 100% !important; text-size-adjust: 100% !important; }';
      var parent = document.head || document.documentElement;
      if (parent && typeof parent.appendChild === 'function') {
        parent.appendChild(style);
      }
    } catch (_) {}
  }

  function computeViewportContent(viewWidth, measureContent) {
    var vw = (typeof viewWidth === 'number' && viewWidth > 0) ? viewWidth : currentViewWidth;
    if (!(vw > 0)) vw = 390;
    var targetWidth = vw >= DESKTOP_BASE_WIDTH ? Math.round(vw) : DESKTOP_BASE_WIDTH;
    if (measureContent && vw < DESKTOP_BASE_WIDTH) {
      try {
        var docEl = document.documentElement;
        var body = document.body;
        var measured = Math.max(
          docEl && docEl.scrollWidth ? docEl.scrollWidth : 0,
          body && body.scrollWidth ? body.scrollWidth : 0
        );
        if (measured > DESKTOP_BASE_WIDTH && measured <= DESKTOP_MAX_WIDTH) {
          targetWidth = measured;
        }
      } catch (_) {}
    }
    var fitScale = Math.max(0.2, Math.min(1.0, vw / targetWidth));
    var minScale = Math.max(0.15, Math.min(fitScale, fitScale * 0.8));
    return {
      fitScale: fitScale,
      content: 'width=' + targetWidth +
        ', initial-scale=' + fitScale.toFixed(4) +
        ', minimum-scale=' + minScale.toFixed(4) +
        ', maximum-scale=3.0, user-scalable=yes'
    };
  }

  function isUserZoomedIn(fitScale) {
    try {
      var vv = window.visualViewport;
      if (!vv || typeof vv.scale !== 'number') return false;
      return vv.scale > fitScale * 1.15;
    } catch (_) {
      return false;
    }
  }

  function applyDesktopViewport(viewWidth, measureContent) {
    if (updatingViewport) return;
    if (typeof viewWidth === 'number' && viewWidth > 0) {
      currentViewWidth = viewWidth;
    }
    var computed = computeViewportContent(currentViewWidth, !!measureContent);
    var content = computed.content;
    var widthChanged = Math.abs(currentViewWidth - lastAppliedViewWidth) >= 2;
    updatingViewport = true;
    try {
      ensureDesktopFitStyle();
      var metas = typeof document.querySelectorAll === 'function'
        ? document.querySelectorAll('meta[name="viewport"], meta[name="VIEWPORT"]')
        : [];
      var primary = null;
      for (var i = 0; i < metas.length; i++) {
        if (!primary) {
          primary = metas[i];
        } else if (metas[i].parentNode && typeof metas[i].parentNode.removeChild === 'function') {
          metas[i].parentNode.removeChild(metas[i]);
        }
      }
      if (!primary && typeof document.createElement === 'function') {
        primary = document.createElement('meta');
        primary.setAttribute('name', 'viewport');
        var host = document.head || document.documentElement;
        if (host && typeof host.appendChild === 'function') {
          host.appendChild(primary);
        }
      } else if (primary && document.head && primary.parentNode !== document.head &&
          typeof document.head.appendChild === 'function') {
        document.head.appendChild(primary);
      }
      if (primary && typeof primary.setAttribute === 'function') {
        var existing = primary.getAttribute('content') || '';
        var siteHijacked = existing.indexOf('device-width') !== -1 ||
          existing.indexOf('user-scalable=no') !== -1 ||
          existing.indexOf('width=') === -1;
        if (!widthChanged && lastAppliedContent && !siteHijacked && isUserZoomedIn(computed.fitScale)) {
          return;
        }
        if (existing !== content) {
          primary.setAttribute('content', content);
        }
        lastAppliedContent = content;
        lastAppliedViewWidth = currentViewWidth;
      }
    } catch (_) {
    } finally {
      updatingViewport = false;
    }
  }

  window.__simpleLiveApplyDesktopViewport = function (viewWidth) {
    applyDesktopViewport(viewWidth, true);
  };

  // 禁止网页内直播流自动播放（搜索网页仅用于浏览、登录和选房，避免手机 WebView 软解视频卡顿）。
  try {
    var proto = window.HTMLMediaElement && window.HTMLMediaElement.prototype;
    if (proto && !proto.__simpleLiveOrigPlay) {
      proto.__simpleLiveOrigPlay = proto.play;
      proto.play = function () {
        try {
          this.autoplay = false;
          this.muted = true;
          this.pause();
        } catch (_) {}
        return Promise.resolve();
      };
    }
  } catch (_) {}

  function silenceMedia(root) {
    if (!root || typeof root.querySelectorAll !== 'function') return;
    var nodes = root.querySelectorAll('video,audio');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      try {
        el.autoplay = false;
        el.muted = true;
        el.preload = 'none';
        if (!el.paused) el.pause();
      } catch (_) {}
    }
  }

  var mediaTimer = null;
  function scheduleSilence() {
    if (mediaTimer) return;
    mediaTimer = setTimeout(function () {
      mediaTimer = null;
      silenceMedia(document);
    }, 300);
  }

  function hasOverriddenViewport() {
    if (typeof document.querySelectorAll !== 'function') return false;
    var metas = document.querySelectorAll('meta[name="viewport"], meta[name="VIEWPORT"]');
    if (!metas || metas.length !== 1) return true;
    var meta = metas[0];
    if (document.head && meta.parentNode && meta.parentNode !== document.head) {
      return true;
    }
    if (typeof meta.getAttribute !== 'function') return true;
    var cur = meta.getAttribute('content') || '';
    return cur !== lastAppliedContent;
  }

  applyDesktopViewport(currentViewWidth, false);

  try {
    if (typeof MutationObserver === 'function') {
      var observer = new MutationObserver(function (mutations) {
        var added = false;
        var viewportTouched = false;
        for (var i = 0; i < mutations.length; i++) {
          var m = mutations[i];
          if (m.type === 'attributes' && m.target &&
              m.target.tagName && m.target.tagName.toUpperCase() === 'META') {
            viewportTouched = true;
          }
          if (m.addedNodes && m.addedNodes.length > 0) {
            added = true;
            for (var j = 0; j < m.addedNodes.length; j++) {
              var node = m.addedNodes[j];
              if (node && node.tagName) {
                var tag = node.tagName.toUpperCase();
                if (tag === 'META' || tag === 'HEAD') {
                  viewportTouched = true;
                }
              }
            }
          }
        }
        if ((viewportTouched || added) && !updatingViewport && hasOverriddenViewport()) {
          applyDesktopViewport(currentViewWidth, false);
        }
        if (added) {
          scheduleSilence();
        }
      });
      var attachObserver = function () {
        var target = document.documentElement || document.body;
        if (target) {
          observer.observe(target, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['content']
          });
        }
        applyDesktopViewport(currentViewWidth, true);
        silenceMedia(document);
      };
      if (document.documentElement) attachObserver();
      else document.addEventListener('DOMContentLoaded', attachObserver, { once: true });
    }
  } catch (_) {}

  document.addEventListener('DOMContentLoaded', function () {
    applyDesktopViewport(currentViewWidth, true);
  }, { once: true });

  window.addEventListener('load', function () {
    applyDesktopViewport(currentViewWidth, true);
  });

  function reportHref(href) {
    if (typeof href !== 'string' || !href) return;
    var bridge = window.flutter_inappwebview;
    if (!bridge || typeof bridge.callHandler !== 'function') return;
    try {
      var url = new URL(href, window.location.href);
      if (url.protocol !== 'http:' && url.protocol !== 'https:') return;
      var pending = bridge.callHandler('simpleLiveSearchRoom', url.href);
      if (pending && typeof pending.catch === 'function') pending.catch(function () {});
    } catch (_) {}
  }

  var lastHref = window.location.href;
  function syncLocation() {
    var cur = window.location.href;
    if (cur !== lastHref) {
      lastHref = cur;
      reportHref(cur);
    }
  }

  var blockedSchemeRe = /^(yykiwi|huya|douyutv|bilibili|snssdk\\d*|intent|market|tel|weixin|alipays):/i;
  document.addEventListener('click', function (event) {
    var target = event.target;
    if (target && target.nodeType !== 1) target = target.parentElement;
    var link = target && typeof target.closest === 'function' && target.closest('a[href]');
    if (link) {
      var rawHref = typeof link.getAttribute === 'function' ? (link.getAttribute('href') || '') : (link.href || '');
      if (blockedSchemeRe.test(rawHref)) {
        if (typeof event.preventDefault === 'function') event.preventDefault();
        if (typeof event.stopPropagation === 'function') event.stopPropagation();
        return;
      }
      if (link.target === '_blank' && typeof link.removeAttribute === 'function') {
        link.removeAttribute('target');
      }
    }
    setTimeout(syncLocation, 250);
    setTimeout(syncLocation, 800);
  }, true);

  setInterval(syncLocation, 1000);
})();
''';
  }
}
