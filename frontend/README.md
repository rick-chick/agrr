# Frontend

This project was generated using [Angular CLI](https://github.com/angular/angular-cli) version 21.1.1.

## Development server

To start a local development server, run:

```bash
ng serve
```

Once the server is running, open your browser and navigate to `http://localhost:4200/`. The application will automatically reload whenever you modify any of the source files.

## Code scaffolding

Angular CLI includes powerful code scaffolding tools. To generate a new component, run:

```bash
ng generate component component-name
```

For a complete list of available schematics (such as `components`, `directives`, or `pipes`), run:

```bash
ng generate --help
```

## Building

To build the project run:

```bash
ng build
```

This will compile your project and store the build artifacts in the `dist/` directory. By default, the production build optimizes your application for performance and speed.

## Running unit tests

To execute unit tests with the [Vitest](https://vitest.dev/) test runner, use the following command:

```bash
ng test
```

## Running end-to-end tests

For end-to-end (e2e) testing, run:

```bash
ng e2e
```

Angular CLI does not come with an end-to-end testing framework by default. You can choose one that suits your needs.

## Additional Resources

For more information on using the Angular CLI, including detailed command references, visit the [Angular CLI Overview and Command Reference](https://angular.dev/tools/cli) page.

## i18n detection helpers

The frontend includes helpers under `frontend/scripts` that detect untranslated text before it ships:

- `npm run extract-i18n` extracts every literal UI string to `frontend/i18n-extraction/keys.json`.
- `npm run check-hardcoded-i18n` looks for Japanese text that still lingers in templates/TypeScript **and** flags elements with button-like classes (e.g., `btn-primary`, `mat-raised-button`) that render text without a `translate` attribute or pipe.
- `npm run check-ja-values` reports `ja.json` entries whose existing translations contain no Japanese characters, helping you spot English placeholders that slipped into the Japanese file. The output lands in `frontend/i18n-extraction/ja-value-report.json`.

Run these scripts as part of the repository's i18n completion workflow so the reports stay green before merging.
