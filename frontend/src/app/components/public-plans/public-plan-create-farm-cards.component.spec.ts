import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { vi } from 'vitest';
import { PublicPlanCreateComponent } from './public-plan-create.component';
import {
  PUBLIC_PLAN_CREATE_PROVIDERS,
} from '../../usecase/public-plans/public-plan-create.providers';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { FlashMessageService } from '../../services/flash-message.service';

describe('PublicPlanCreateComponent farm selection cards', () => {
  let fixture: ComponentFixture<PublicPlanCreateComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PublicPlanCreateComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        ...PUBLIC_PLAN_CREATE_PROVIDERS,
        PublicPlanStore,
        { provide: FlashMessageService, useValue: { show: vi.fn() } },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(PublicPlanCreateComponent);
  });

  it('renders shared farm selection cards when farms are loaded', async () => {
    fixture.detectChanges();
    const component = fixture.componentInstance;
    component.control = {
      loading: false,
      error: null,
      farms: [
        { id: 10, name: 'Tokyo Farm', latitude: 35.6, longitude: 139.6, region: 'jp' },
      ],
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-farm-selection-cards')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.enhanced-selection-card')?.textContent).toContain(
      'Tokyo Farm',
    );
  });
});
