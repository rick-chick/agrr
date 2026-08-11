import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  CROP_LABELS,
  fixEnglishAnchors,
  fixResearchCta,
  gddSimulateCtaEn,
  normalizeSectionHeadings,
  slugifyHeading,
  temperatureSimulateCtaEn,
} from './bulk-translate-research-en-lib.mjs';

describe('slugifyHeading', () => {
  it('lowercases, strips punctuation, and hyphenates spaces', () => {
    assert.equal(slugifyHeading('Growing Degree Days (GDD)'), 'growing-degree-days-gdd');
  });

  it('truncates long headings to 80 characters', () => {
    const long = 'A'.repeat(100);
    assert.equal(slugifyHeading(long).length, 80);
  });
});

describe('normalizeSectionHeadings', () => {
  it('renames leading Summary h2 to Overview', () => {
    const html =
      '<h2>Summary<a class="header-anchor" href="#summary">#</a></h2><p>Intro</p>';
    const next = normalizeSectionHeadings(html);
    assert.match(next, /<h2>Overview<a class="header-anchor"/);
    assert.doesNotMatch(next, /<h2>Summary/);
  });

  it('renames trailing Summary h2 to Conclusion when no conclusion exists', () => {
    const html =
      '<h2>Overview</h2><p>Body</p><h2>Summary</h2><p>Wrap up</p>';
    const next = normalizeSectionHeadings(html);
    assert.match(next, /<h2>Conclusion<\/h2>/);
    assert.doesNotMatch(next, /<h2>Summary<\/h2>/);
  });

  it('leaves Summary unchanged when Conclusion already present', () => {
    const html =
      '<h2>Overview</h2><p>Body</p><h2>Conclusion</h2><p>Done</p><h2>Summary</h2>';
    assert.equal(normalizeSectionHeadings(html), html);
  });
});

describe('fixEnglishAnchors', () => {
  it('rewrites heading ids and anchor hrefs from English titles', () => {
    const html =
      '<h2 id="old-id" tabindex="-1">Growing Degree Days<a class="header-anchor" href="#old-id" aria-label="Permalink to &quot;Growing Degree Days&quot;">#</a></h2>';
    const next = fixEnglishAnchors(html);
    assert.match(next, /id="growing-degree-days"/);
    assert.match(next, /href="#growing-degree-days"/);
  });
});

describe('fixResearchCta', () => {
  const jaGddCta =
    '<div class="tip custom-block agrr-gdd-simulate-cta"><p>地域で試す</p></div>';

  it('replaces JA GDD CTA with English crop-specific CTA', () => {
    const next = fixResearchCta(jaGddCta, 'potato', 'gdd_requirements');
    assert.match(next, /Simulate Potato cultivation/);
    assert.match(next, /agrr-gdd-simulate-cta/);
    assert.doesNotMatch(next, /地域で試す/);
  });

  it('uses temperature CTA template for temperature_requirements report', () => {
    const jaTempCta =
      '<div class="tip custom-block agrr-temperature-simulate-cta"><p>温度</p></div>';
    const next = fixResearchCta(jaTempCta, 'tomato', 'temperature_requirements');
    assert.match(next, /temperature requirements apply/);
    assert.match(next, /Simulate Tomato cultivation/);
    assert.match(next, /agrr-temperature-simulate-cta/);
  });

  it('falls back to crop slug when label is unknown', () => {
    const next = fixResearchCta(jaGddCta, 'mystery_crop', 'gdd_requirements');
    assert.match(next, /Simulate mystery_crop cultivation/);
  });
});

describe('CTA templates', () => {
  it('includes public-plans link and crop label', () => {
    assert.match(gddSimulateCtaEn('Broccoli'), /https:\/\/agrr\.net\/public-plans\/new/);
    assert.match(temperatureSimulateCtaEn('Broccoli'), /Broccoli cultivation/);
  });

  it('defines labels for all translated crops', () => {
    const crops = [
      'bell_pepper',
      'broccoli',
      'cabbage',
      'carrot',
      'chinese_cabbage',
      'corn',
      'cucumber',
      'eggplant',
      'lettuce',
      'onion',
      'potato',
      'pumpkin',
      'radish',
      'spinach',
      'tomato',
    ];
    for (const crop of crops) {
      assert.ok(CROP_LABELS[crop], `missing label for ${crop}`);
    }
  });
});
