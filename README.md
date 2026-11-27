# PetCareServices

A Flutter login screen for the PetCareServices admin app.

## Backend integration

The login form posts JSON to `https://preservation-owners-felt-feedback.trycloudflare.com/users/api/login` with `email` and `password`. On success, it reads `bearerToken`, `refreshToken`, and `expiresIn`, then requests `GET /users/api/menulinks` with `Authorization: Bearer <bearerToken>`. Tokens are held in memory only and are never displayed or saved locally.

## Architecture

The app follows Clean Architecture with MVVM:

- `core/`: constants, errors, and API configuration
- `domain/`: entities, repository contracts, and use cases
- `data/`: HTTP data sources and repository implementations
- `presentation/`: Flutter screens and ChangeNotifier view models

UI widgets depend on view models and domain abstractions. Network and JSON handling stay in the data layer, so they can be tested independently.

## Run

```bash
flutter pub get
flutter run
```
