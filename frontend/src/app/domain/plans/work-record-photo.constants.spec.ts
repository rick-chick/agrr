import { describe, expect, it } from 'vitest';
import {
  WORK_RECORD_PHOTO_THUMB_ASPECT_RATIO,
  WORK_RECORD_PHOTO_THUMB_WIDTH_HISTORY,
  WORK_RECORD_PHOTO_THUMB_WIDTH_SHEET
} from './work-record-photo.constants';

describe('work-record-photo.constants', () => {
  it('uses landscape 4:3 aspect ratio for thumbnails in list and sheet', () => {
    expect(WORK_RECORD_PHOTO_THUMB_ASPECT_RATIO).toBe('4 / 3');
    expect(WORK_RECORD_PHOTO_THUMB_WIDTH_HISTORY).toBe('4rem');
    expect(WORK_RECORD_PHOTO_THUMB_WIDTH_SHEET).toBe('4.5rem');
  });
});
