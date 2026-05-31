import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, expect, it, beforeEach } from 'vitest';
import { RegionSelectComponent } from './region-select.component';

describe('RegionSelectComponent', () => {
  let fixture: ComponentFixture<RegionSelectComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RegionSelectComponent, TranslateModule.forRoot()]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      shared: {
        region_select: {
          label: 'Region',
          blank: 'Please select',
          jp: 'Japan',
          us: 'US',
          in: 'India'
        }
      }
    });
    translate.use('en');

    fixture = TestBed.createComponent(RegionSelectComponent);
    fixture.detectChanges();
  });

  it('renders shared.region_select label', () => {
    const label = fixture.nativeElement.querySelector('label');
    expect(label?.textContent?.trim()).toBe('Region');
  });
});
