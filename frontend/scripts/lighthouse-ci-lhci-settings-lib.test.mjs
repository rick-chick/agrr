import assert from 'node:assert/strict';
import { test } from 'node:test';

import { collectSettingsForPreset } from './lighthouse-ci-lhci-settings-lib.mjs';

test('collectSettingsForPreset maps semantic mobile to formFactor (not invalid preset)', () => {
  const settings = collectSettingsForPreset('mobile');
  assert.equal(settings.formFactor, 'mobile');
  assert.equal(settings.preset, undefined);
  assert.equal(settings.screenEmulation?.mobile, true);
});

test('collectSettingsForPreset passes through desktop preset', () => {
  assert.deepEqual(collectSettingsForPreset('desktop'), { preset: 'desktop' });
});
