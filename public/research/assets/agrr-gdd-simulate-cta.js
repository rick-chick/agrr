(function () {
  var CROP_LABELS = {
    tomato: { ja: 'トマト', en: 'tomato' },
    potato: { ja: 'じゃがいも', en: 'potato' },
    bell_pepper: { ja: 'ピーマン', en: 'bell pepper' },
    eggplant: { ja: 'ナス', en: 'eggplant' },
    cucumber: { ja: 'キュウリ', en: 'cucumber' },
    pumpkin: { ja: 'かぼちゃ', en: 'pumpkin' },
    carrot: { ja: '人参', en: 'carrot' },
    radish: { ja: '大根', en: 'radish' },
    onion: { ja: '玉ねぎ', en: 'onion' },
    cabbage: { ja: 'キャベツ', en: 'cabbage' },
    broccoli: { ja: 'ブロッコリー', en: 'broccoli' },
    chinese_cabbage: { ja: '白菜', en: 'Chinese cabbage' },
    lettuce: { ja: 'レタス', en: 'lettuce' },
    spinach: { ja: 'ほうれん草', en: 'spinach' },
    corn: { ja: 'トウモロコシ', en: 'corn' }
  };

  function isGddPage() {
    return /\/gdd_requirements(\.html)?$/.test(window.location.pathname);
  }

  function cropSlugFromPath() {
    var match = window.location.pathname.match(/research_reports\/([^/]+)\//);
    return match ? match[1] : null;
  }

  function isEnglishPage() {
    return /\/research\/en\//.test(window.location.pathname);
  }

  function buildCta(slug) {
    var labels = CROP_LABELS[slug];
    if (!labels) return null;
    var en = isEnglishPage();
    var cropLabel = en ? labels.en : labels.ja;
    var title = en
      ? 'Simulate ' + cropLabel + ' GDD with weather in your region'
      : cropLabel + 'のGDDを、あなたの地域の気象でシミュレーション';
    var body = en
      ? 'Visualize planting timing and cumulative GDD using local weather data (free).'
      : '地域の気象データで作付け時期と積算温度の推移を可視化できます（無料）。';
    var button = en ? 'Start simulation →' : '無料でシミュレーション →';
    var params =
      'crop=' +
      encodeURIComponent(slug) +
      '&utm_source=research&utm_medium=gdd_cta&utm_content=' +
      encodeURIComponent(slug);
    var href = '/public-plans/new?' + params;

    var box = document.createElement('aside');
    box.className = 'agrr-gdd-simulate-cta';
    box.setAttribute('role', 'note');
    box.innerHTML =
      '<p class="agrr-gdd-simulate-cta__title">' +
      title +
      '</p><p class="agrr-gdd-simulate-cta__body">' +
      body +
      '</p><a class="agrr-gdd-simulate-cta__link" href="' +
      href +
      '">' +
      button +
      '</a>';
    return box;
  }

  function findInsertPoint(doc) {
    var headings = doc.querySelectorAll('.vp-doc h2');
    for (var i = 0; i < headings.length; i++) {
      var text = headings[i].textContent || '';
      if (!/総括一覧表|summary table|overview table/i.test(text)) continue;
      var node = headings[i].nextElementSibling;
      while (node) {
        if (node.tagName === 'TABLE') return node;
        var nested = node.querySelector && node.querySelector('table');
        if (nested) return nested;
        if (node.tagName === 'H2') break;
        node = node.nextElementSibling;
      }
    }
    for (var j = 0; j < headings.length; j++) {
      var hText = headings[j].textContent || '';
      if (/まとめ|conclusion|summary$/i.test(hText.trim())) {
        return headings[j];
      }
    }
    return doc.querySelector('.vp-doc h1');
  }

  function inject() {
    if (!isGddPage()) return;
    var slug = cropSlugFromPath();
    if (!slug) return;
    var doc = document.querySelector('.vp-doc');
    if (!doc || doc.querySelector('.agrr-gdd-simulate-cta')) return;
    var cta = buildCta(slug);
    if (!cta) return;
    var anchor = findInsertPoint(doc);
    if (!anchor) return;
    if (anchor.tagName === 'TABLE') {
      anchor.insertAdjacentElement('afterend', cta);
    } else {
      anchor.insertAdjacentElement('beforebegin', cta);
    }
  }

  function scheduleInject() {
    window.requestAnimationFrame(function () {
      inject();
    });
  }

  if (!document.getElementById('agrr-gdd-simulate-cta-style')) {
    var style = document.createElement('style');
    style.id = 'agrr-gdd-simulate-cta-style';
    style.textContent =
      '.agrr-gdd-simulate-cta{margin:1.5rem 0;padding:1rem 1.25rem;border:1px solid var(--vp-c-brand-1,#3eaf7c);border-radius:8px;background:var(--vp-c-bg-soft,#f6f8fa)}' +
      '.dark .agrr-gdd-simulate-cta{background:var(--vp-c-bg-alt,#1e1e20)}' +
      '.agrr-gdd-simulate-cta__title{margin:0 0 .5rem;font-weight:600;font-size:1.05rem}' +
      '.agrr-gdd-simulate-cta__body{margin:0 0 .75rem;color:var(--vp-c-text-2,#476582)}' +
      '.agrr-gdd-simulate-cta__link{display:inline-block;padding:.45rem .9rem;border-radius:6px;background:var(--vp-c-brand-1,#3eaf7c);color:#fff;font-weight:600;text-decoration:none}' +
      '.agrr-gdd-simulate-cta__link:hover{opacity:.92}';
    document.head.appendChild(style);
  }

  document.addEventListener('DOMContentLoaded', scheduleInject);
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
