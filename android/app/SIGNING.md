# Android Upload Key — `upload-keystore.jks`

The `flutter-aab-final` workflow signs the Play Store AAB with a Java
KeyStore committed to **`android/app/upload-keystore.jks`**. The
keystore itself is binary and **must be committed to the repo by you**
— it can't be reconstructed from the SHA fingerprints below; those are
one-way hashes derived from the key.

## Expected fingerprints (registered with Play Console)

```
SHA-1   : C2:27:D7:BE:A2:38:70:40:16:6A:E3:D9:BD:23:39:8D:60:DC:08:DE
SHA-256 : 76:E1:49:7A:35:36:DD:9A:02:8C:DB:46:5F:F8:D2:38:18:C0:FC:40:A2:55:53:C5:C7:AB:CF:2B:A7:5C:BD:ED
```

The workflow's `Verify keystore` step prints SHA-1 to the build log so
you can eyeball-match it against the value above. If they differ, the
keystore in the repo is the wrong one.

## Keystore creds (must match `flutter-aab-final.yml`)

```
keystore  : android/app/upload-keystore.jks
alias     : skeletalpt
storepass : skeletalpt123
keypass   : skeletalpt123
```

`build.gradle.kts` reads these from env vars (set by the workflow)
with a hardcoded fallback to the same values, so a local
`flutter build appbundle --release` Just Works once the .jks is in
place.

## How to drop in the keystore

1. Find your existing `upload-keystore.jks` (the one whose fingerprints
   are registered with Play Console — values above).
2. Copy it to `android/app/upload-keystore.jks` in this repo.
3. `git add android/app/upload-keystore.jks && git commit -m "Add upload keystore"`
4. Push. The workflow will pick it up on the next run.

## If you've lost the keystore

If you opted into Play App Signing, Google holds the **app signing
key** for you and you only need a fresh **upload key** — generate a
new one and upload the new SHA-256 to Play Console under
*Setup → App integrity → Upload key certificate → Reset upload key*.

Generate command:

```sh
keytool -genkey -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias skeletalpt \
  -storepass skeletalpt123 -keypass skeletalpt123 \
  -dname "CN=Mirrorly,O=Mirrorly,C=GB"
```

Then read the new SHA-256:

```sh
keytool -list -v \
  -keystore android/app/upload-keystore.jks \
  -alias skeletalpt -storepass skeletalpt123 \
  | grep "SHA256:"
```

Submit that to Play Console and update the value at the top of this
file.

## Security note

Committing a real keystore + creds to the repo is a security trade-off
the team has explicitly chosen here (workflow YAML already pastes the
creds in plaintext). If this repo ever goes public, **rotate this key
and use Play Console's "Reset upload key" flow** before publishing.
