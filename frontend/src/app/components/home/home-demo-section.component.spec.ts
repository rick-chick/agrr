import { describe, it, expect, vi, beforeEach } from 'vitest';
import { HomeDemoSectionComponent } from './home-demo-section.component';

describe('HomeDemoSectionComponent (class-level)', () => {
  let component: HomeDemoSectionComponent;
  let router: { navigate: ReturnType<typeof vi.fn> };
  let demoStore: { syncFromTranslate: ReturnType<typeof vi.fn> };
  let translate: {
    instant: ReturnType<typeof vi.fn>;
    onLangChange: { subscribe: ReturnType<typeof vi.fn> };
  };

  beforeEach(() => {
    router = { navigate: vi.fn() };
    demoStore = { syncFromTranslate: vi.fn().mockReturnValue(null) };
    translate = {
      instant: vi.fn((key: string) => key),
      onLangChange: { subscribe: vi.fn().mockReturnValue({ unsubscribe: vi.fn() }) }
    };

    component = Object.create(HomeDemoSectionComponent.prototype) as HomeDemoSectionComponent;
    (component as unknown as { router: typeof router }).router = router;
    (component as unknown as { demoStore: typeof demoStore }).demoStore = demoStore;
    (component as unknown as { translate: typeof translate }).translate = translate;
  });

  it('navigateToPlan routes to public plan creation', () => {
    HomeDemoSectionComponent.prototype.navigateToPlan.call(component);

    expect(router.navigate).toHaveBeenCalledWith(['/public-plans/new']);
  });

  it('ngOnInit syncs demo data from translate service', () => {
    HomeDemoSectionComponent.prototype.ngOnInit.call(component);

    expect(demoStore.syncFromTranslate).toHaveBeenCalledWith(translate);
    expect(translate.onLangChange.subscribe).toHaveBeenCalled();
  });
});
