# 画面完結 Shared コンポーネント デザインパターン

## 概要

画面完結UIロジックを再利用可能なsharedコンポーネントに分離するためのデザインパターン集。

## パターン一覧

### 1. Event Handler パターン

**目的**: クリック、ホバー、タイマーなどの純粋なUIイベント処理を分離

**特徴**:
- 外部APIやUseCaseを呼ばない
- Input/Outputのみで親コンポーネントと連携
- Angular MaterialなどのUIライブラリと組み合わせやすい

**構造**:
```typescript
@Component({
  selector: 'app-click-outside-handler',
  standalone: true,
  template: `<ng-content></ng-content>`
})
export class ClickOutsideHandlerComponent {
  @Output() clickedOutside = new EventEmitter<void>();

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: Event) {
    if (!this.elementRef.nativeElement.contains(event.target)) {
      this.clickedOutside.emit();
    }
  }
}
```

### 2. State Manager パターン

**目的**: ローカルUI状態（開閉、アコーディオン、フォーム状態）を管理

**特徴**:
- コンポーネント内部で完結する状態管理
- 親コンポーネントへの通知はOutput経由
- 複雑な状態遷移ロジックをカプセル化

**構造**:
```typescript
export class AccordionStateManagerComponent {
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

### 3. Timer Manager パターン

**目的**: カウントダウン、ポーリング、アニメーションタイマーを管理

**特徴**:
- RxJS Timer/Intervalを使用
- 自動クリーンアップ
- 親コンポーネントへの通知

**構造**:
```typescript
export class CountdownTimerComponent implements OnDestroy {
  @Input() duration = 60;
  @Output() timeUp = new EventEmitter<void>();
  @Output() tick = new EventEmitter<number>();

  private destroy$ = new Subject<void>();
  remainingTime = signal(this.duration);

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

### 4. Form State パターン

**目的**: バリデーション状態、エラーメッセージ表示を管理

**特徴**:
- Angular Reactive Formsとの連携
- エラー状態の視覚化
- ユーザー入力フィードバック

**構造**:
```typescript
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

### 5. Modal/Dialog Manager パターン

**目的**: モーダル開閉、アニメーション、フォーカス管理

**特徴**:
- Angular Material DialogやPrimeNGとの連携
- キーボード操作対応
- アクセシビリティ対応

**構造**:
```typescript
export class ModalManagerComponent {
  @Input() isOpen = false;
  @Output() closed = new EventEmitter<void>();

  private focusTrap: FocusTrap | null = null;

  ngOnChanges(changes: SimpleChanges) {
    if (changes['isOpen']) {
      if (this.isOpen) {
        this.setupFocusTrap();
      } else {
        this.destroyFocusTrap();
      }
    }
  }

  @HostListener('document:keydown.escape')
  onEscape() {
    if (this.isOpen) {
      this.closed.emit();
    }
  }

  private setupFocusTrap() {
    // Focus trap implementation
  }
}
```

## 共通原則

### 1. 依存性の分離
- Gateway/UseCase/Serviceを注入しない
- 外部API呼び出しを行わない
- HTTPクライアントを使用しない

### 2. Input/Output中心
- 親コンポーネントからのデータ受け取りは`@Input`
- 親コンポーネントへの通知は`@Output`またはコールバック
- 双方向データバインディングは避ける

### 3. 再利用性
- 汎用的なインターフェース設計
- 設定可能な動作（Input経由）
- 複数のコンポーネントで使用可能

### 4. テスト容易性
- 純粋関数的なロジック
- 副作用の最小化
- イベントベースのテストが可能