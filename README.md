# meteoride

# Meteoride — dokumentacja projektu

Wersja: 0.1.0  
Data: 2025-11-09  
Autor: nnar1o

Krótki opis
----------
Aplikacja mobilna dla osób jeżdżących na rowerze lub motocyklu. Rano wysyła powiadomienie, czy pogoda jest odpowiednia do jazdy (rower/motocykl) czy lepiej wybrać samochód. Minimalna wersja (MVP) działa bez logowania profili.

Zasady wersjonowania
---------------------
Używamy SemVer. Przy każdej zmianie funkcjonalnej podbijamy wersję:
- Major.Minor.Patch — np. 0.1.0 → 0.2.0 dla nowych funkcji, 0.1.1 dla poprawek.

Architektura (skrót)
--------------------
- Mobile: Flutter (UI komercyjny, atrakcyjny design). Testy UI: Patrol.
- Backend: Rust — lekki, tani w hostowaniu.
- Zewnętrzne: WeatherAPI (dostęp do prognoz).
- Cache: Redis — cache granic mapy (kwadraty/geohash).
- Deployment: Docker + Kubernetes.
- Konfiguracja: YAML.

MVP — wymagania funkcjonalne
----------------------------
Mobile:
- Wybór trybu: rower albo motocykl.
- Ustawienie lokalizacji (automatycznie przez GPS + możliwość ręcznego wyboru).
- Włącz/wyłącz powiadomienia i ustawienie godziny powiadomienia.
- Odbieranie porannego powiadomienia: „Dziś pogoda OK na rower/motor” albo „Lepiej auto”.
- Estetyczne UI gotowe do komercjalizacji.

Backend:
- Endpoint(y) udostępniające ocenę warunków pogodowych dla podanej lokalizacji i pojazdu.
- Pobieranie prognozy z WeatherAPI.
- Cache w Redis (klucze wg geohash/siatki + typ pojazdu) z TTL i automatyczną inwalidacją.
- Konfiguracja w YAML (klucze API, cache TTL, reguły oceny).
- Testy jednostkowe + szybkie testy uruchamiane w kontenerze.

Szczegóły techniczne — backend (Rust)
-------------------------------------
Główne komponenty:
- API server (actix-web lub axum — lekki i szybki).
- Moduł integracji z WeatherAPI (odpowiedzialny za fetching i mapowanie danych).
- Logika oceny warunków (reguły per vehicle: max wiatr, opady, temp, widoczność, oblodzenie).
- Cache: Redis (async client).
- Konfiguracja: plik YAML ładowany przy starcie (dotenv + yaml).

Proponowany endpoint (MVP)
- GET /v1/ride-safety?lat={lat}&lon={lon}&vehicle={bike|motor}
  - Response: JSON { safe: bool, score: number, reason: string[], forecast_meta: {...} }

Cache
- Klucz: ride:{geohash}:{vehicle}:{provider_version}
- Geohash/siatka: zaokrąglanie lat/lon (np. 4-6 znaków geohash lub 0.01°) zależnie od wymaganej precyzji.
- TTL: konfigurowalny (np. 15 min).
- Mechanizm: przy żądaniu — sprawdź cache → jeśli brak → pobierz z WeatherAPI → zapisz do Redis z TTL → zwróć.

Konfiguracja YAML — przykład
```yaml
server:
  host: "0.0.0.0"
  port: 8080

weatherapi:
  key: "${WEATHER_API_KEY}"
  provider: "WeatherAPI"
  base_url: "https://api.weatherapi.com/v1"

cache:
  redis_url: "redis://redis:6379/0"
  ttl_seconds: 900   # 15 minut
  geohash_precision: 5

rules:
  bike:
    max_wind_kph: 30
    max_precip_mm: 3
    min_temp_c: -5
  motor:
    max_wind_kph: 60
    max_precip_mm: 10
    min_temp_c: -10
```

Testy — backend
---------------
- Unit tests: `cargo test` (logika, parsowanie, reguły).
- Integracyjne: uruchomienie kontenera z Redis + uruchomienie testów integracyjnych (można mockować WeatherAPI).
- Szybkie testy w kontenerze:
  - Dockerfile z targetem testowym (stage test) i `cargo test --release`.
  - Przy CI: uruchomić redis w jobie (service) i odpalić testy.
- Zalecane użycie: testy jednostkowe w CI (szybkie), integracyjne uruchamiane na merge do main.

Kontenery i Kubernetes
----------------------
- Dockerfile (multi-stage): budowanie w rust:slim → mały obraz wynikowy (distroless/Alpine).
- K8s: Deployment, Service, ConfigMap (yaml config), Secret (API key), HorizontalPodAutoscaler.
- Resource limits: niskie CPU/RAM — aplikacja ma być lekka.

Przykładowy fragment Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: meteoride-backend
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: backend
          image: myregistry/meteoride-backend:0.1.0
          envFrom:
            - secretRef:
                name: meteoride-secrets
            - configMapRef:
                name: meteoride-config
          resources:
            limits:
              cpu: "500m"
              memory: "256Mi"
```

Mobile — Flutter
----------------
Stack:
- Flutter (stable)
- Patrol — do end-to-end / UI tests
- Lokalizacja: geolocator / location
- Powiadomienia: flutter_local_notifications / platform-specific
- UI: komercyjny design, animacje, motyw, gotowe assety, attention to polish UX

Funkcje MVP (mobile):
- Ekran główny: status dla wybranej lokalizacji.
- Konfiguracja: wybór pojazdu, lokalizacji, powiadomień, godziny. Dodatkowo mozliwosc konfiguracji warunków pogodowych do jazdy rowere/motocyklem.
- Historia ostatnich ocen (opcjonalnie lokalne cache).
- Ustawienia: tryb jasny/ciemny, jednostki (metric/imperial).
- prognoza na caly dzien wyswietlana w oknie

Testy UI (Patrol) — szybkie uruchamianie
- Cel: szybkie testy bez emulatora → uruchamiać testy na Web (Chrome) gdzie to możliwe.
- Rekomendacja:
  - Przygotować testy Patrol kompatybilne z platformą web.
  - Uruchamiać w CI na maszynach z headless Chrome.
- Przykładowy przebieg:
  1. Uruchom backend testowy (mock WeatherAPI lub lokalne API).
  2. Uruchom Flutter w trybie web (debug) hostując aplikację.
  3. Uruchom Patrol / integration tests kierując na Chrome (headless).
- Jeśli testy wymagają natywnych API (powiadomienia, GPS) — ograniczyć do integracji lokalnych (wtedy emulator jest potrzebny) lub zamockować platformowe pluginy.

Przykładowe komendy (przykładowe, dopasować do projektu / Patrol):
```bash
# uruchom backend mock / dev
./scripts/run-dev-backend.sh

# uruchom flutter web
flutter run -d chrome

# uruchom patrol tests (web)
patrol test --target test_driver/app_test.dart --device web-server
```
(Uwaga: dopasować komendy do wersji Patrol/Flutter; celem — preferować platformę web dla szybkości.)

Integracja Mobile <-> Backend
-----------------------------
- Mobile wysyła zapytanie do backendu z lat/lon i typem pojazdu (cron/scheduler lokalny wyzwala rano).
- Backend zwraca ocenę i krótkie powody (np. "silny wiatr", "opady").
- Mobile decyduje o treści notyfikacji.

Bezpieczeństwo i koszt
----------------------
- Trzymać klucz WeatherAPI w Secret (K8s Secret / env vars).
- Ograniczyć liczbę zapytań do WeatherAPI przez agresywny cache i grupowanie zapytań po siatce.
- Binary w Rust minimalizuje koszty hostingu.
- Dodać monitoring zużycia API i alerty kosztowe.

CI/CD i release
---------------
- GitHub Actions:
  - Job build-backend (cargo build, cargo test).
  - Job build-mobile (flutter analyze, flutter test).
  - Job publish Docker image (tag z wersją).
  - Job deploy to k8s (manual on release or auto on main).
- Przy każdym releasie: podnieść wersję (CHANGELOG), tag release.

Roadmapa (propozycja wersji)
----------------------------
v0.1.0 (MVP) — minimalne
- Backend w Rust z cache w Redis, GET /v1/ride-safety
- Flutter app: wybór pojazdu, lokalizacja, powiadomienia rano, ładne UI
- Testy jednostkowe backend + podstawowe Patrol UI testy uruchamiane na web
- Docker + K8s deployment manifests

v0.2.0 — ulepszenia użyteczności
- Lokalna historia i prosty dashboard
- Ustawienia progów bezpieczeństwa (użytkownik może zmieniać tolerancję)
- Więcej testów E2E i automatyzacja CI dla Patrol (web)

v0.3.0 — konta i personalizacja
- Logowanie (oauth/email)
- Profile z ulubionymi trasami / automatyczne przypomnienia przy trasie
- Integracja z mapami i zapisywanie ulubionych lokalizacji

v1.0.0 — komercyjne wydanie
- Płatne funkcje (pro): alerty SMS, integracja z kalendarzem, prognozy godzinowe
- Lokalizacje offline, wsparcie dla wielu języków
- Pełny zestaw testów, SLA, monitoring i backup

Funkcje możliwe w przyszłości (pomysły)
- Integracja z pasami pogodowymi (radar opadów)
- Wykrywanie niebezpiecznych warunków drogowych (np. mróz/śliskość) z dodatkowymi datasource
- Społeczność: raporty użytkowników (niebezpieczne odcinki)
- Integracja z wearables (szybkie alerty)

Przykładowy workflow deweloperski
--------------------------------
1. Fork/branch feature/x
2. Implementuj backend + testy (podnieś patch version w Cargo.toml)
3. Implementuj mobile + testy UI (podnieś wersję w pubspec.yaml)
4. CI uruchamia testy; po green — PR do main
5. Merge → release pipeline buduje obrazy i deployuje

Dodatkowe uwagi
---------------
- Dokumentacja powinna być aktualizowana przy każdej zmianie (bump wersji).
- UI powinien być zoptymalizowany pod sprzedaż: onboarding, ładne ikony, klarowny komunikat powiadomień.
- Jeśli zależy nam na niskich kosztach — cache i ograniczanie liczby requestów do WeatherAPI to klucz.

Pliki konfiguracyjne i przykłady
--------------------------------
W repo powinny się znaleźć:
- backend/
  - Cargo.toml (z wersją)
  - src/
  - config/default.yaml
  - Dockerfile
  - k8s/deployment.yaml
  - tests/
- mobile/
  - pubspec.yaml (z wersją)
  - lib/
  - integration_test/ (Patrol)
  - scripts/ (uruchamianie testów web)
- infra/
  - helm/ lub manifests/

Kontakt / kolejne kroki
-----------------------
Jeśli chcesz, przygotuję:
- szczegółowy spec API (pełny OpenAPI),
- przykładowy Dockerfile i manifest K8s,
- szablon config/default.yaml z opisami pól,
- przykładowe reguły oceny pogody (konkretne progi).
