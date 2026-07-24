(function () {
  var SIDEBAR_CTA_CLASS = 'agrr-research-sidebar-cta';
  var MOBILE_CTA_CLASS = 'agrr-research-mobile-cta';
  var INLINE_CTA_CLASS = 'agrr-gdd-simulate-cta';
  var MOBILE_BREAKPOINT_PX = 960;

  var CROP_LABELS = {
    tomato: { ja: 'トマト', en: 'Tomato' },
    potato: { ja: 'じゃがいも', en: 'Potato' },
    bell_pepper: { ja: 'ピーマン', en: 'Bell pepper' },
    eggplant: { ja: 'ナス', en: 'Eggplant' },
    cucumber: { ja: 'キュウリ', en: 'Cucumber' },
    pumpkin: { ja: 'かぼちゃ', en: 'Pumpkin' },
    carrot: { ja: '人参', en: 'Carrot' },
    radish: { ja: '大根', en: 'Radish' },
    onion: { ja: '玉ねぎ', en: 'Onion' },
    cabbage: { ja: 'キャベツ', en: 'Cabbage' },
    broccoli: { ja: 'ブロッコリー', en: 'Broccoli' },
    chinese_cabbage: { ja: '白菜', en: 'Chinese cabbage' },
    lettuce: { ja: 'レタス', en: 'Lettuce' },
    spinach: { ja: 'ほうれん草', en: 'Spinach' },
    corn: { ja: 'トウモロコシ', en: 'Corn' }
  };

  function isResearchRequirementsPage() {
    return /\/(gdd_requirements|temperature_requirements)(\.html)?$/.test(
      window.location.pathname
    );
  }

  function pageTypeFromPath() {
    if (/\/temperature_requirements/.test(window.location.pathname)) {
      return 'temperature';
    }
    if (/\/gdd_requirements/.test(window.location.pathname)) {
      return 'gdd';
    }
    return null;
  }

  function cropSlugFromPath() {
    var match = window.location.pathname.match(/research_reports\/([^/]+)\//);
    return match ? match[1] : null;
  }

  function isEnglishPage() {
    return /\/research\/en\//.test(window.location.pathname);
  }

  function buildPublicPlanHref(slug, utmMedium) {
    var params = 'crop=' + encodeURIComponent(slug);
    if (utmMedium) {
      params +=
        '&utm_source=research&utm_medium=' +
        encodeURIComponent(utmMedium) +
        '&utm_content=' +
        encodeURIComponent(slug);
    }
    return '/public-plans/new?' + params;
  }

  function buildSidebarCopy(slug, pageType) {
    var labels = CROP_LABELS[slug];
    if (!labels) return null;
    var en = isEnglishPage();
    var cropLabel = en ? labels.en : labels.ja;
    var title = en ? 'Try it in your region' : 'あなたの地域で試す';
    var body;
    if (pageType === 'temperature') {
      body = en
        ? 'See how ' + cropLabel + ' temperature requirements apply to your local weather.'
        : cropLabel + 'の温度要件を、お住まいの地域の気象データに当てはめて確認できます。';
    } else {
      body = en
        ? 'Simulate ' + cropLabel + ' GDD with weather in your region.'
        : cropLabel + 'のGDDを、あなたの地域の気象でシミュレーションできます。';
    }
    var button = en ? 'Simulate →' : 'シミュレート →';
    return { title: title, body: body, button: button };
  }

  function buildMobileCopy(slug) {
    var labels = CROP_LABELS[slug];
    if (!labels) return null;
    var en = isEnglishPage();
    var cropLabel = en ? labels.en : labels.ja;
    return {
      label: en ? 'Try ' + cropLabel + ' in your region' : cropLabel + 'をあなたの地域で試す',
      button: en ? 'Simulate →' : 'シミュレート →'
    };
  }

  function hideInlineCtas(doc) {
    doc.querySelectorAll('.vp-doc .' + INLINE_CTA_CLASS).forEach(function (el) {
      el.classList.add('agrr-research-inline-cta--hidden');
    });
  }

  function buildSidebarCta(slug, pageType) {
    var copy = buildSidebarCopy(slug, pageType);
    if (!copy) return null;
    var href = buildPublicPlanHref(slug, 'temp_sidebar');
    var box = document.createElement('aside');
    box.className = SIDEBAR_CTA_CLASS;
    box.setAttribute('role', 'complementary');
    box.innerHTML =
      '<p class="' +
      SIDEBAR_CTA_CLASS +
      '__title">' +
      copy.title +
      '</p><p class="' +
      SIDEBAR_CTA_CLASS +
      '__body">' +
      copy.body +
      '</p><a class="' +
      SIDEBAR_CTA_CLASS +
      '__link" href="' +
      href +
      '">' +
      copy.button +
      '</a>';
    return box;
  }

  function buildMobileCta(slug) {
    var copy = buildMobileCopy(slug);
    if (!copy) return null;
    var href = buildPublicPlanHref(slug, 'temp_mobile');
    var bar = document.createElement('div');
    bar.className = MOBILE_CTA_CLASS;
    bar.setAttribute('role', 'region');
    bar.setAttribute('aria-label', copy.label);
    bar.innerHTML =
      '<span class="' +
      MOBILE_CTA_CLASS +
      '__label">' +
      copy.label +
      '</span><a class="' +
      MOBILE_CTA_CLASS +
      '__link" href="' +
      href +
      '">' +
      copy.button +
      '</a>';
    return bar;
  }

  function findSidebar() {
    return document.querySelector('.VPDocAside') || document.querySelector('.VPSidebar');
  }

  function injectSidebarCta(slug, pageType) {
    var sidebar = findSidebar();
    if (!sidebar || sidebar.querySelector('.' + SIDEBAR_CTA_CLASS)) return;
    var cta = buildSidebarCta(slug, pageType);
    if (!cta) return;
    sidebar.appendChild(cta);
  }

  function injectMobileCta(slug) {
    if (document.querySelector('.' + MOBILE_CTA_CLASS)) return;
    var cta = buildMobileCta(slug);
    if (!cta) return;
    document.body.appendChild(cta);
  }

  function removeResearchCtas() {
    document.querySelectorAll('.' + SIDEBAR_CTA_CLASS).forEach(function (el) {
      el.remove();
    });
    document.querySelectorAll('.' + MOBILE_CTA_CLASS).forEach(function (el) {
      el.remove();
    });
    document.querySelectorAll('.agrr-research-inline-cta--hidden').forEach(function (el) {
      el.classList.remove('agrr-research-inline-cta--hidden');
    });
  }

  function inject() {
    if (!isResearchRequirementsPage()) {
      removeResearchCtas();
      return;
    }
    var slug = cropSlugFromPath();
    var pageType = pageTypeFromPath();
    if (!slug || !pageType) return;

    var doc = document.querySelector('.vp-doc');
    if (doc) {
      hideInlineCtas(doc);
    }
    injectSidebarCta(slug, pageType);
    injectMobileCta(slug);
  }

  function scheduleInject() {
    window.requestAnimationFrame(function () {
      inject();
    });
  }

  if (!document.getElementById('agrr-research-cta-style')) {
    var style = document.createElement('style');
    style.id = 'agrr-research-cta-style';
    style.textContent =
      '.agrr-research-inline-cta--hidden{display:none!important}' +
      '.' +
      SIDEBAR_CTA_CLASS +
      '{margin-top:1.5rem;padding:1rem 1.25rem;border:1px solid var(--vp-c-brand-1,#3eaf7c);border-radius:8px;background:var(--vp-c-bg-soft,#f6f8fa);position:sticky;bottom:1rem;z-index:1}' +
      '.dark .' +
      SIDEBAR_CTA_CLASS +
      '{background:var(--vp-c-bg-alt,#1e1e20)}' +
      '.' +
      SIDEBAR_CTA_CLASS +
      '__title{margin:0 0 .5rem;font-weight:600;font-size:1rem;line-height:1.35}' +
      '.' +
      SIDEBAR_CTA_CLASS +
      '__body{margin:0 0 .75rem;color:var(--vp-c-text-2,#476582);font-size:.9rem;line-height:1.45}' +
      '.' +
      SIDEBAR_CTA_CLASS +
      '__link{display:inline-block;padding:.5rem 1rem;border-radius:6px;background:var(--vp-c-brand-1,#3eaf7c);color:#fff;font-weight:600;text-decoration:none;text-align:center}' +
      '.' +
      SIDEBAR_CTA_CLASS +
      '__link:hover{opacity:.92}' +
      '.' +
      MOBILE_CTA_CLASS +
      '{display:none;position:fixed;left:0;right:0;bottom:0;z-index:var(--vp-z-index-local-nav,50);align-items:center;justify-content:space-between;gap:.75rem;padding:.75rem 1rem;background:var(--vp-c-bg,#fff);border-top:1px solid var(--vp-c-divider,#e2e8f0);box-shadow:0 -4px 16px rgba(0,0,0,.08)}' +
      '.dark .' +
      MOBILE_CTA_CLASS +
      '{background:var(--vp-c-bg-alt,#1e1e20)}' +
      '.' +
      MOBILE_CTA_CLASS +
      '__label{flex:1;font-size:.9rem;font-weight:600;line-height:1.3;color:var(--vp-c-text-1,#213547)}' +
      '.' +
      MOBILE_CTA_CLASS +
      '__link{flex-shrink:0;display:inline-block;padding:.5rem 1rem;border-radius:6px;background:var(--vp-c-brand-1,#3eaf7c);color:#fff;font-weight:600;text-decoration:none;white-space:nowrap}' +
      '.' +
      MOBILE_CTA_CLASS +
      '__link:hover{opacity:.92}' +
      '@media (max-width:' +
      (MOBILE_BREAKPOINT_PX - 1) +
      'px){.' +
      SIDEBAR_CTA_CLASS +
      '{display:none}.' +
      MOBILE_CTA_CLASS +
      '{display:flex}}' +
      '@media (min-width:' +
      MOBILE_BREAKPOINT_PX +
      'px){.' +
      MOBILE_CTA_CLASS +
      '{display:none!important}}';
    document.head.appendChild(style);
  }

  function observeSidebar() {
    if (!window.MutationObserver) return;
    var observer = new MutationObserver(function () {
      scheduleInject();
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  document.addEventListener('DOMContentLoaded', function () {
    scheduleInject();
    observeSidebar();
  });

  (function () {
    function wrap(method) {
      var orig = history[method];
      if (typeof orig !== 'function') return;
      history[method] = function () {
        var rv = orig.apply(this, arguments);
        scheduleInject();
        return rv;
      };
    }
    wrap('pushState');
    wrap('replaceState');
    window.addEventListener('popstate', scheduleInject);
  })();
})();
