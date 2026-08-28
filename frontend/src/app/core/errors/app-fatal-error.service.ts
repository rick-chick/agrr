import { Injectable, signal } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class AppFatalErrorService {
  private readonly fatalError = signal<unknown | null>(null);

  readonly hasFatalError = () => this.fatalError() !== null;

  setFatalError(error: unknown): void {
    this.fatalError.set(error);
  }
}
