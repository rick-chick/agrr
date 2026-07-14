# 画面完結 Shared コンポーネント 実装例

## 概要

各デザインパターンの実際の使用例とコードサンプル。

## 1. Event Handler 例: Click Outside Handler

### 使用例
ドロップダウンやモーダルの外部クリック検知に使用。

```typescript
// shared/click-outside-handler.component.ts
import { Component, ElementRef, EventEmitter, HostListener, Output } from '@angular/core';

@Component({
  selector: 'app-click-outside-handler',
  standalone: true,
  template: `<ng-content></ng-content>`
})
export class ClickOutsideHandlerComponent {
  @Output() clickedOutside = new EventEmitter<void>();

  constructor(private elementRef: ElementRef) {}

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: Event) {
    if (!this.elementRef.nativeElement.contains(event.target)) {
      this.clickedOutside.emit();
    }
  }
}
```

### 親コンポーネントでの使用

```typescript
// feature.component.ts
export class FeatureComponent {
  dropdownOpen = false;

  onClickedOutside() {
    this.dropdownOpen = false;
  }
}
```

```html
<!-- feature.component.html -->
<app-click-outside-handler (clickedOutside)="onClickedOutside()">
  <div class="dropdown" [class.open]="dropdownOpen">
    <button (click)="dropdownOpen = !dropdownOpen">Toggle</button>
    <div *ngIf="dropdownOpen" class="dropdown-menu">
      <!-- menu items -->
    </div>
  </div>
</app-click-outside-handler>
```

## 2. State Manager 例: Accordion Manager

### 使用例
アコーディオンUIの開閉状態管理。

```typescript
// shared/accordion-manager.component.ts
import { Component, EventEmitter, Input, Output } from '@angular/core';

export interface AccordionItem {
  title: string;
  content: string;
}

@Component({
  selector: 'app-accordion-manager',
  standalone: true,
  template: `
    <div class="accordion-item" *ngFor="let item of items; let i = index">
      <button (click)="toggleItem(i)">
        {{ item.title }}
        <span>{{ isExpanded(i) ? '▼' : '▶' }}</span>
      </button>
      <div *ngIf="isExpanded(i)" class="accordion-content">
        {{ item.content }}
      </div>
    </div>
  `
})
export class AccordionManagerComponent {
  @Input() items: AccordionItem[] = [];
  @Output() itemToggled = new EventEmitter<number>();

  private expandedItems = new Set<number>();

  toggleItem(index: number) {
    if (this.expandedItems.has(index)) {
      this.expandedItems.delete(index);
    } else {
      this.expandedItems.add(index);
    }
    this.itemToggled.emit(index);
  }

  isExpanded(index: number): boolean {
    return this.expandedItems.has(index);
  }
}
```

### 親コンポーネントでの使用

```typescript
// feature.component.ts
export class FeatureComponent {
  accordionItems: AccordionItem[] = [
    { title: 'Section 1', content: 'Content 1...' },
    { title: 'Section 2', content: 'Content 2...' }
  ];

  onItemToggled(index: number) {
    console.log(`Item ${index} toggled`);
  }
}
```

## 3. Timer Manager 例: Countdown Timer

### 使用例
クイズや制限時間のある機能に使用。

```typescript
// shared/countdown-timer.component.ts
import { Component, EventEmitter, Input, OnDestroy, OnInit, Output } from '@angular/core';
import { interval, Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';

@Component({
  selector: 'app-countdown-timer',
  standalone: true,
  template: `
    <div class="timer">
      <span>{{ remainingTime() }}</span>
      <span>seconds remaining</span>
    </div>
  `
})
export class CountdownTimerComponent implements OnInit, OnDestroy {
  @Input() duration = 60;
  @Output() timeUp = new EventEmitter<void>();
  @Output() tick = new EventEmitter<number>();

  remainingTime = signal(this.duration);
  private destroy$ = new Subject<void>();

  ngOnInit() {
    interval(1000)
      .pipe(takeUntil(this.destroy$))
      .subscribe(() => {
        const current = this.remainingTime();
        if (current > 0) {
          this.remainingTime.set(current - 1);
          this.tick.emit(current - 1);
        } else {
          this.timeUp.emit();
        }
      });
  }

  ngOnDestroy() {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

### 親コンポーネントでの使用

```typescript
// quiz.component.ts
export class QuizComponent {
  onTimeUp() {
    // Handle time up
    this.submitQuiz();
  }

  onTick(remaining: number) {
    if (remaining === 10) {
      // Show warning
    }
  }
}
```

## 4. Form State 例: Field State Manager

### 使用例
フォームフィールドのバリデーション状態表示。

```typescript
// shared/form-field-state.component.ts
import { Component, Input } from '@angular/core';
import { FormControl } from '@angular/forms';

@Component({
  selector: 'app-form-field-state',
  standalone: true,
  template: `
    <div class="form-field">
      <label>{{ label }}</label>
      <input [formControl]="control" [class.error]="hasError">
      <div *ngIf="hasError" class="error-message">
        {{ errorMessage }}
      </div>
    </div>
  `,
  styles: [`
    .error { border-color: red; }
    .error-message { color: red; font-size: 0.8em; }
  `]
})
export class FormFieldStateComponent {
  @Input() control!: FormControl;
  @Input() label = '';
  @Input() errorMessages: Record<string, string> = {};

  get hasError(): boolean {
    return this.control.invalid && this.control.touched;
  }

  get errorMessage(): string {
    if (!this.hasError) return '';
    const errorKey = Object.keys(this.control.errors!)[0];
    return this.errorMessages[errorKey] || 'Invalid input';
  }
}
```

### 親コンポーネントでの使用

```typescript
// registration.component.ts
export class RegistrationComponent {
  emailControl = new FormControl('', [Validators.required, Validators.email]);
  passwordControl = new FormControl('', [Validators.required, Validators.minLength(8)]);

  errorMessages = {
    required: 'This field is required',
    email: 'Please enter a valid email',
    minlength: 'Password must be at least 8 characters'
  };
}
```

## 5. Modal Manager 例: Modal State Handler

### 使用例
モーダルの開閉とフォーカス管理。

```typescript
// shared/modal-state-handler.component.ts
import { Component, EventEmitter, HostListener, Input, Output } from '@angular/core';

@Component({
  selector: 'app-modal-state-handler',
  standalone: true,
  template: `
    <div class="modal-backdrop" *ngIf="isOpen" (click)="closeModal()">
      <div class="modal-content" (click)="$event.stopPropagation()">
        <ng-content></ng-content>
        <button (click)="closeModal()">Close</button>
      </div>
    </div>
  `
})
export class ModalStateHandlerComponent {
  @Input() isOpen = false;
  @Output() closed = new EventEmitter<void>();

  @HostListener('document:keydown.escape')
  onEscape() {
    if (this.isOpen) {
      this.closed.emit();
    }
  }

  closeModal() {
    this.closed.emit();
  }
}
```

### 親コンポーネントでの使用

```typescript
// feature.component.ts
export class FeatureComponent {
  showModal = false;

  openModal() {
    this.showModal = true;
  }

  closeModal() {
    this.showModal = false;
  }
}
```

## 実装時の注意点

### 1. 依存性の確認
- sharedコンポーネントがUseCaseやGatewayに依存していないことを確認
- 必要なInput/Outputのみを定義

### 2. テスト容易性
- 各コンポーネントは独立してテスト可能
- Outputイベントの発火をテスト

### 3. パフォーマンス
- OnPush ChangeDetectionを使用可能
- 不要な再描画を避ける

### 4. アクセシビリティ
- キーボード操作に対応
- ARIA属性を適切に設定
- フォーカス管理を実装