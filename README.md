# Helmfile Render Manifests Action

Use helmfile to render application manifests for use with GitOps controllers

### Inputs

| Name        | Required | Default   | Description                                                                                        |
| ----------- | :------: | --------- | -------------------------------------------------------------------------------------------------- |
| `app`       |    ✅    | `n/a`     | The app to render manifests for.                                                                   |
| `targets`   |    🚫    | `""`      | The targets to render manifests for.                                                               |
| `app-dir`   |    🚫    | `""`      | The base directory for app deployment config. If not set will be inferred using the app name.      |
| `out-dir`   |    🚫    | `""`      | The directory to sync rendered manfiests to relative to project root. If not set will be inferred. |
| `sync`      |    🚫    | `"true"`  | Sync rendered manifests to `out-dir`                                                               |
| `skip-deps` |    🚫    | `"false"` | Set to true to skip building dependencies (`helmfile dep`)                                         |
