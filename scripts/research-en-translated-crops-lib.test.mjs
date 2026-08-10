import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  EN_TRANSLATED_CROPS,
  isTranslatedEnResearchRelativePath,
  parseResearchCropFromRelativePath,
  shouldInjectResearchHreflang,
} from './research-en-translated-crops-lib.mjs';

describe('parseResearchCropFromRelativePath', () => {
  it('extracts crop slug from JA and EN report paths', () => {
    assert.equal(
      parseResearchCropFromRelativePath(
        'research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
      ),
      'tomato'
    );
    assert.equal(
      parseResearchCropFromRelativePath(
        'en/research_reports/potato/02_nutrition/npk_absorption.html'
      ),
      'potato'
    );
  });

  it('returns null for index pages', () => {
    assert.equal(parseResearchCropFromRelativePath('index.html'), null);
    assert.equal(parseResearchCropFromRelativePath('en/index.html'), null);
  });
});

describe('isTranslatedEnResearchRelativePath', () => {
  it('allows JA pages and locale index pages', () => {
    assert.equal(isTranslatedEnResearchRelativePath('index.html'), true);
    assert.equal(isTranslatedEnResearchRelativePath('en/index.html'), true);
    assert.equal(
      isTranslatedEnResearchRelativePath(
        'research_reports/potato/01_environmental_requirements/temperature_requirements.html'
      ),
      true
    );
  });

  it('allows EN pages only for translated crops', () => {
    assert.equal(
      isTranslatedEnResearchRelativePath(
        'en/research_reports/tomato/01_environmental_requirements/temperature_requirements.html'
      ),
      true
    );
    assert.equal(
      isTranslatedEnResearchRelativePath(
        'en/research_reports/potato/01_environmental_requirements/temperature_requirements.html'
      ),
      true
    );
  });

  it('rejects EN pages for crops outside EN_TRANSLATED_CROPS', () => {
    assert.equal(
      isTranslatedEnResearchRelativePath(
        'en/research_reports/watermelon/01_environmental_requirements/temperature_requirements.html'
      ),
      false
    );
  });
});

describe('shouldInjectResearchHreflang', () => {
  it('injects hreflang for locale index pairs', () => {
    assert.equal(shouldInjectResearchHreflang('index.html', true), true);
    assert.equal(shouldInjectResearchHreflang('en/index.html', true), true);
  });

  it('injects hreflang only when crop EN translation is complete', () => {
    const jaTomato =
      'research_reports/tomato/01_environmental_requirements/gdd_requirements.html';
    const enTomato =
      'en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html';
    const jaPotato =
      'research_reports/potato/01_environmental_requirements/temperature_requirements.html';

    assert.equal(shouldInjectResearchHreflang(jaTomato, true), true);
    assert.equal(shouldInjectResearchHreflang(enTomato, true), true);
    assert.equal(shouldInjectResearchHreflang(jaPotato, true), true);
  });

  it('does not inject when alternate locale file is missing', () => {
    assert.equal(
      shouldInjectResearchHreflang(
        'research_reports/tomato/01_environmental_requirements/gdd_requirements.html',
        false
      ),
      false
    );
  });

  it('does not inject hreflang for EN crop pages outside EN_TRANSLATED_CROPS', () => {
    const enWatermelon =
      'en/research_reports/watermelon/01_environmental_requirements/gdd_requirements.html';
    assert.equal(shouldInjectResearchHreflang(enWatermelon, true), false);
  });
});

describe('EN_TRANSLATED_CROPS', () => {
  it('includes all 15 research crops', () => {
    const expected = [
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
    assert.deepEqual([...EN_TRANSLATED_CROPS].sort(), expected.sort());
  });
});
