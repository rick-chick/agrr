/**
 * Maps semantic Lighthouse CI route presets to valid LHCI collect.settings.
 * LHCI 0.14+ only accepts preset: desktop | perf | experimental — not "mobile".
 *
 * @param {string} preset
 * @returns {Record<string, unknown>}
 */
export function collectSettingsForPreset(preset) {
  if (preset === 'mobile') {
    return {
      formFactor: 'mobile',
      screenEmulation: {
        mobile: true,
        width: 412,
        height: 823,
        deviceScaleFactor: 1.75,
        disabled: false,
      },
    };
  }

  return { preset };
}
