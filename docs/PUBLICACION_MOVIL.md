# Publicacion movil POSIA (Google Play y App Store)

**Version de tienda:** 1.0.0 (build 1)  
**Paquete Android:** `com.posia.posia_pos`  
**Bundle iOS:** `com.posia.posiaPos`

---

## Release con GitHub Actions (sin Mac)

El workflow **Mobile Release** compila Android (AAB + APK) en Ubuntu e **iOS (IPA) en `macos-latest`**, sin necesidad de Mac local.

| Disparador | Cuando |
|------------|--------|
| Manual | Actions → **Mobile Release** → Run workflow |
| Tag | `git tag mobile-v1.0.0 && git push origin mobile-v1.0.0` |

Artefactos: pestaña **Artifacts** del run, o **GitHub Releases** si usaste tag `mobile-v*`.

### 1. Configurar secrets (una sola vez)

Repositorio → **Settings → Secrets and variables → Actions → New repository secret**

Desde Windows, genera el base64 del keystore:

```powershell
.\scripts\preparar_secretos_github.ps1
```

#### Android (obligatorio para AAB firmado)

| Secret | Valor |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | Salida del script (keystore en base64) |
| `ANDROID_KEYSTORE_PASSWORD` | Contrasena del keystore |
| `ANDROID_KEY_PASSWORD` | Contrasena de la clave |
| `ANDROID_KEY_ALIAS` | `posia` |

Sin estos secrets el CI compila con firma debug (no valido para Play Store).

#### iOS (App Store sin Mac)

| Secret | Valor |
|--------|-------|
| `IOS_DIST_CERTIFICATE_BASE64` | Certificado distribucion `.p12` en base64 |
| `IOS_DIST_CERTIFICATE_PASSWORD` | Contrasena del `.p12` |
| `IOS_PROVISION_PROFILE_BASE64` | Perfil App Store `.mobileprovision` en base64 |
| `IOS_PROVISION_PROFILE_NAME` | Nombre exacto del perfil |
| `APPLE_TEAM_ID` | Team ID de Apple Developer |
| `KEYCHAIN_PASSWORD` | String cualquiera (solo CI) |

Obtener certificado y perfil: [Apple Developer](https://developer.apple.com/account) → Certificates, Identifiers & Profiles → App ID `com.posia.posiaPos`.

### 2. Ejecutar release

**Opcion A — desde GitHub (recomendado)**

1. Configura los secrets anteriores
2. Actions → **Mobile Release** → **Run workflow** → platform: `all`
3. Descarga `posia-android-aab` y `posia-ios-ipa` en Artifacts

**Opcion B — tag automatico + GitHub Release**

```bash
git tag mobile-v1.0.0
git push origin mobile-v1.0.0
```

Crea un Release en GitHub con los binarios adjuntos.

### 3. Subir a tiendas

- **Play Store:** sube `app-release.aab` desde Artifacts
- **App Store Connect:** sube el `.ipa` con [Transporter](https://apps.apple.com/app/transporter/id1450874784) o `xcrun altool` desde cualquier PC

---

## Build local (alternativa)

### Android

```powershell
.\scripts\generar_keystore_android.ps1   # una sola vez
.\scripts\build_movil_release.ps1 -Plataforma android
```

**AAB:** `apps/posia_pos/build/app/outputs/bundle/release/app-release.aab`

### iOS (solo con Mac local)

```bash
cd apps/posia_pos
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

---

## Google Play Console

1. [Google Play Console](https://play.google.com/console) → **POSIA**
2. Produccion → Subir `app-release.aab`
3. Politica de privacidad: publicar [PRIVACIDAD.md](PRIVACIDAD.md) en URL publica
4. Capturas, clasificacion IARC, seguridad de datos
5. **Notas para el revisor:** tienda cualquiera, usuario `1000`, PIN `1234`

---

## App Store Connect

1. [App Store Connect](https://appstoreconnect.apple.com) → **POSIA**
2. Bundle ID: `com.posia.posiaPos`
3. App Privacy: microfono y voz para caja; sin seguimiento
4. Export compliance: `ITSAppUsesNonExemptEncryption = false` (ya en Info.plist)
5. Mismas credenciales demo en notas para el revisor

---

## Versiones futuras

En `apps/posia_pos/pubspec.yaml`:

```yaml
version: 1.0.1+2
```

Tag de release: `mobile-v1.0.1`

---

## Registro

| Fecha | Cambio |
|-------|--------|
| 2026-06-21 | Workflow GitHub Actions mobile-release (Android + iOS) |
| 2026-06-21 | Documento inicial store-ready v1.0.0 |
