import type { CDPSession, Locator, Page } from '@playwright/test';

export type TouchSwipeHandle = {
  /** hold 時に touchEnd 送信用。touchSwipeOnLocator と同一 CDP セッションを使う */
  cdp: CDPSession;
};

/**
 * CDP で TouchEvent を送る（mouse / Playwright drag ではない）。
 * Chrome は touch から PointerEvent を合成するため、実機のガント操作に近い。
 */
export async function touchSwipeOnLocator(
  page: Page,
  locator: Locator,
  deltaX: number,
  options?: { steps?: number; end?: 'release' | 'hold' },
): Promise<TouchSwipeHandle> {
  const box = await locator.boundingBox();
  if (!box) {
    throw new Error('touch swipe target has no bounding box');
  }

  const startX = box.x + box.width / 2;
  const startY = box.y + box.height / 2;
  const steps = options?.steps ?? 12;
  const cdp = await page.context().newCDPSession(page);

  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchStart',
    touchPoints: [{ x: startX, y: startY }],
  });

  for (let i = 1; i <= steps; i++) {
    const x = startX + (deltaX * i) / steps;
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: [{ x, y: startY }],
    });
    await page.waitForTimeout(16);
  }

  if (options?.end !== 'hold') {
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchEnd',
      touchPoints: [],
    });
  }

  return { cdp };
}

/** touchStart 済み・touchMove 済みのあと、指を離す */
export async function touchRelease(cdp: CDPSession): Promise<void> {
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchEnd',
    touchPoints: [],
  });
}

export function dayDiffIso(isoA: string, isoB: string): number {
  const a = new Date(isoA.slice(0, 10));
  const b = new Date(isoB.slice(0, 10));
  return Math.abs(Math.round((b.getTime() - a.getTime()) / 86_400_000));
}
