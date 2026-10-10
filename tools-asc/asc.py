#!/usr/bin/env python3
"""App Store Connect API yardımcı aracı (yalnızca standart kütüphane + openssl).
Kullanım:
  asc.py screenshots   → docs/appstore/{en,tr}/*.png dosyalarını Mac ekran görüntüsü olarak yükler
  asc.py review        → App Review iletişim bilgisi (signing/review-contact.json) ve notlarını kaydeder
  asc.py builds        → yüklenen build'lerin işlenme durumunu gösterir
  asc.py attach        → işlenmiş en son build'i 1.0 sürümüne bağlar
Ayarlar: signing/asc.json (git dışında) ya da ASC_KEY_ID / ASC_ISSUER / ASC_APP_ID; anahtar ~/.appstoreconnect/private_keys/AuthKey_<ID>.p8
"""
import base64, hashlib, json, os, subprocess, sys, time, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Yerel ayarlar git dışında: signing/asc.json  {"key_id": "...", "issuer": "...", "app_id": "..."}
_cfg = {}
_cfgp = os.path.join(ROOT, "signing", "asc.json")
if os.path.exists(_cfgp): _cfg = json.load(open(_cfgp))
KEY_ID = os.environ.get("ASC_KEY_ID", _cfg.get("key_id", ""))
ISSUER = os.environ.get("ASC_ISSUER", _cfg.get("issuer", ""))
APP_ID = os.environ.get("ASC_APP_ID", _cfg.get("app_id", ""))
if not (KEY_ID and ISSUER and APP_ID): raise SystemExit("signing/asc.json ya da ASC_KEY_ID / ASC_ISSUER / ASC_APP_ID gerekli")
KEY = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
API = "https://api.appstoreconnect.apple.com"

def b64u(b): return base64.urlsafe_b64encode(b).rstrip(b"=")

def der_to_raw(der):
    # ECDSA-Sig-Value ::= SEQUENCE { r INTEGER, s INTEGER } → r||s (32+32)
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7f)
    out = b""
    for _ in range(2):
        assert der[i] == 0x02; ln = der[i + 1]; v = der[i + 2:i + 2 + ln]; i += 2 + ln
        out += v.lstrip(b"\x00").rjust(32, b"\x00")
    return out

_tok = None
def token():
    global _tok
    if _tok and _tok[1] > time.time() + 60: return _tok[0]
    now = int(time.time()); exp = now + 1100
    h = b64u(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    p = b64u(json.dumps({"iss": ISSUER, "iat": now, "exp": exp, "aud": "appstoreconnect-v1"}).encode())
    msg = h + b"." + p
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY], input=msg, capture_output=True, check=True).stdout
    _tok = ((msg + b"." + b64u(der_to_raw(der))).decode(), exp)
    return _tok[0]

def req(method, path, body=None, url=None, headers=None, raw=None):
    u = url or (API + path)
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    h = headers or {"Authorization": "Bearer " + token(), "Content-Type": "application/json"}
    r = urllib.request.Request(u, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            t = resp.read()
            return json.loads(t) if t and resp.headers.get("Content-Type", "").startswith("application/json") else {}
    except urllib.error.HTTPError as e:
        msg = e.read().decode(errors="replace")
        raise SystemExit(f"HTTP {e.code} {method} {u}\n{msg[:1500]}")

def mac_version():
    vs = req("GET", f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=MAC_OS&limit=5")["data"]
    v = [x for x in vs if x["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")] or vs
    return v[0]

def screenshots():
    ver = mac_version()
    locs = req("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")["data"]
    for loc in locs:
        locale = loc["attributes"]["locale"]
        folder = {"en-US": "en", "tr": "tr"}.get(locale)
        if not folder: continue
        files = sorted(f for f in os.listdir(os.path.join(ROOT, "docs/appstore", folder)) if f.endswith(".png"))
        sets = req("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
        sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == "APP_DESKTOP"), None)
        if sset is None:
            sset = req("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_DESKTOP"},
                       "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
        existing = req("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots")["data"]
        have = {s["attributes"]["fileName"] for s in existing}
        for f in files:
            if f in have: print(f"  {locale}: {f} zaten var"); continue
            path = os.path.join(ROOT, "docs/appstore", folder, f)
            blob = open(path, "rb").read()
            shot = req("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": f, "fileSize": len(blob)},
                       "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
            for op in shot["attributes"]["uploadOperations"]:
                part = blob[op["offset"]:op["offset"] + op["length"]]
                hdr = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
                req(op["method"], None, url=op["url"], headers=hdr, raw=part)
            req("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
            print(f"  {locale}: {f} yüklendi")
    print("✔ Ekran görüntüleri yüklendi (Apple birkaç dakika içinde işler)")

def review():
    ver = mac_version()
    contact_path = os.path.join(ROOT, "signing/review-contact.json")
    if not os.path.exists(contact_path):
        sys.exit("signing/review-contact.json yok; tools-asc/review-contact.example.json dosyasını kopyalayıp doldurun")
    with open(contact_path, encoding="utf-8") as f:
        c = json.load(f)
    notes = open(os.path.join(ROOT, "docs/appstore/review-notes.txt"), encoding="utf-8").read().split("Notes:\n", 1)[1].strip()
    attrs = {"contactFirstName": c["firstName"], "contactLastName": c["lastName"], "contactPhone": c["phone"],
             "contactEmail": c["email"], "demoAccountRequired": False, "notes": notes}
    cur = req("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreReviewDetail").get("data")
    if cur:
        req("PATCH", f"/v1/appStoreReviewDetails/{cur['id']}", {"data": {"type": "appStoreReviewDetails", "id": cur["id"], "attributes": attrs}})
    else:
        req("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver["id"]}}}}})
    print("✔ App Review bilgileri kaydedildi")

def builds():
    bs = req("GET", f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=5&fields[builds]=version,processingState,uploadedDate,usesNonExemptEncryption")["data"]
    for b in bs:
        a = b["attributes"]; print(f"  build {a['version']}  {a['processingState']}  {a['uploadedDate']}  encryption={a.get('usesNonExemptEncryption')}  id={b['id']}")
    if not bs: print("  henüz build görünmüyor (işleniyor olabilir)")
    return bs

def attach():
    bs = [b for b in builds() if b["attributes"]["processingState"] == "VALID"]
    if not bs: raise SystemExit("İşlenmiş (VALID) build yok; biraz sonra tekrar deneyin.")
    ver = mac_version()
    req("PATCH", f"/v1/appStoreVersions/{ver['id']}/relationships/build", {"data": {"type": "builds", "id": bs[0]["id"]}})
    print(f"✔ Build {bs[0]['attributes']['version']} sürüm {ver['attributes']['versionString']}'e bağlandı")

def nextbuild():
    """Bu sürüm numarası için bir sonraki build numarası (App Store'daki en büyük + 1)"""
    ver = os.environ.get("APPSTORE_VERSION", "1.0")
    bs = req("GET", f"/v1/builds?filter[app]={APP_ID}&filter[preReleaseVersion.version]={ver}&limit=200&fields[builds]=version")["data"]
    nums = [int(b["attributes"]["version"]) for b in bs if b["attributes"]["version"].isdigit()]
    print(max(nums, default=0) + 1)

def wait_attach():
    """Yüklenen build işlenene kadar bekler (en fazla 30 dk), sonra sürüme bağlar"""
    want = os.environ.get("APPSTORE_BUILD")
    for _ in range(60):
        bs = req("GET", f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=5&fields[builds]=version,processingState")["data"]
        b = next((x for x in bs if x["attributes"]["version"] == want), None) if want else (bs[0] if bs else None)
        state = b["attributes"]["processingState"] if b else "—"
        print(f"  build {want}: {state}", flush=True)
        if state == "VALID":
            ver = mac_version()
            req("PATCH", f"/v1/appStoreVersions/{ver['id']}/relationships/build", {"data": {"type": "builds", "id": b["id"]}})
            print(f"✔ Build {want} sürüm {ver['attributes']['versionString']}'e bağlandı"); return
        if state in ("INVALID", "FAILED"): raise SystemExit("✘ Apple build'i reddetti; App Store Connect'teki e-postaya bakın")
        time.sleep(30)
    raise SystemExit("Zaman aşımı: build hâlâ işleniyor; sonra `asc.py attach` çalıştırın")

if __name__ == "__main__":
    {"screenshots": screenshots, "review": review, "builds": builds, "attach": attach,
     "nextbuild": nextbuild, "wait-attach": wait_attach}[sys.argv[1]]()
