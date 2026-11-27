#!/bin/bash
# Pin シリーズの署名の鍵を、まとめて作る（作者が自分のターミナルで 1 回だけ流す）。
# 決まりの全体は、共通のノート「Pinシリーズの決まり」の 4 の節。
#
# 作るもの:
#   1. 開発用の印鑑「nexy Dev Signing」        … ログインキーチェーン（黙って押せる。開発のビルド用）
#   2. 金庫 nexy-release.keychain-db          … ~/Library/Keychains/（専用のパスワード。ふだんは閉まっている。眠ったら閉まる）
#   3. 配る版用の印鑑「nexy Release Signing」  … 金庫の中
#   4. 更新の鍵（Sparkle・アカウント名 nexy-release） … 金庫の中
#   5. 控え（配る版用の印鑑の .p12・更新の鍵のファイル） … デスクトップの nexy-keys-backup フォルダ
#
# パスワードは、すべてターミナルや Mac の画面で聞く（コマンドの中には書き込まない）。
# 聞かれるパスワード:
#   - 金庫のパスワード（新しく決める。作るときに 2 回、使ってよい相手の設定で 1 回）
#   - Mac のログインパスワード（印鑑を「署名に使ってよい」と信頼する設定で、画面に出る）
#   - 控えの .p12 のパスワード（新しく決める。2 回）
#
# 金庫は、検索リスト（Mac が鍵を探す箱の一覧）に入れたままにしない。
# 入れたままにすると、閉まっている間に開発のビルドなどが金庫を探して、パスワードの画面が出るため。
# 配る版を作るときだけ、scripts/vault.sh が一時的に入れて、終わったら外す。
#
# 変数のすぐ後ろに全角の文字を続けるときは、${NAME} と波かっこで囲む（create-signing-cert.sh と同じ理由）。
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="${HERE}/../Vendor/Sparkle/bin"
LOGIN="$HOME/Library/Keychains/login.keychain-db"
VAULT="$HOME/Library/Keychains/nexy-release.keychain-db"
DEV_NAME="nexy Dev Signing"
REL_NAME="nexy Release Signing"
SPARKLE_ACCOUNT="nexy-release"
BACKUP="$HOME/Desktop/nexy-keys-backup"

say() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

# --- 始める前の確かめ ---
if [ ! -x "${BIN}/generate_keys" ]; then
  echo "Sparkle の道具（${BIN}/generate_keys）がありません。先に make sparkle を流してください。" >&2
  exit 1
fi
if [ -e "${VAULT}" ]; then
  echo "金庫（${VAULT}）はすでにあります。作り直すときは、先に AI に相談してください。" >&2
  exit 1
fi
if security find-certificate -c "${REL_NAME}" >/dev/null 2>&1; then
  echo "「${REL_NAME}」の証明書が、すでにキーチェーンにあります。作り直すときは、先に AI に相談してください。" >&2
  exit 1
fi
if [ -e "${BACKUP}" ]; then
  echo "控えのフォルダ（${BACKUP}）がすでにあります。中身を片付けてから流してください。" >&2
  exit 1
fi

# 途中で止まっても、検索リストと「いつもの箱」（既定のキーチェーン）を元に戻す
ORIG_LIST=()
while IFS= read -r line; do
  ORIG_LIST+=("$(echo "$line" | sed -E 's/^ *"(.*)"$/\1/')")
done < <(security list-keychains -d user)
ORIG_DEFAULT="$(security default-keychain -d user | sed -E 's/^ *"(.*)"$/\1/')"
WORK="$(mktemp -d)"
cleanup() {
  security default-keychain -d user -s "${ORIG_DEFAULT}" 2>/dev/null || true
  security list-keychains -d user -s "${ORIG_LIST[@]}" 2>/dev/null || true
  [ -e "${VAULT}" ] && security lock-keychain "${VAULT}" 2>/dev/null || true
  rm -rf "${WORK}"
}
trap cleanup EXIT

# 証明書と秘密の鍵を作る（期限は日本時間の 9999-12-31。理由は create-signing-cert.sh と同じ）
make_cert() { # make_cert <名前> <書き出す先の頭の名前>
  local name="$1" out="$2" dir
  dir="$(mktemp -d "${WORK}/ca.XXXX")"
  cat > "${dir}/req.cnf" <<EOF
[ req ]
distinguished_name = dn
prompt = no
[ dn ]
CN = ${name}
EOF
  cat > "${dir}/ca.cnf" <<EOF
[ ca ]
default_ca = selfsign
[ selfsign ]
database = ${dir}/index.txt
new_certs_dir = ${dir}
serial = ${dir}/serial
default_md = sha256
policy = policy_any
unique_subject = no
email_in_dn = no
copy_extensions = none
[ policy_any ]
commonName = supplied
[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF
  : > "${dir}/index.txt"
  /usr/bin/openssl rand -hex 16 > "${dir}/serial"
  /usr/bin/openssl req -new -newkey rsa:2048 -nodes \
    -keyout "${out}.key.pem" -out "${dir}/req.csr" -config "${dir}/req.cnf" 2>/dev/null
  /usr/bin/openssl ca -batch -selfsign -notext -config "${dir}/ca.cnf" -keyfile "${out}.key.pem" \
    -in "${dir}/req.csr" -out "${out}.cert.pem" -extensions ext -enddate "99991231145959Z" 2>/dev/null
}
sha1_of() { /usr/bin/openssl x509 -in "$1" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g'; }

# --- 1. 開発用の印鑑 ---
say "1/4 開発用の印鑑「${DEV_NAME}」をログインキーチェーンに作る"
echo "（Mac の画面に、ログインパスワードを聞く画面が出たら、入れて「設定をアップデート」を押してください）"
"${HERE}/create-signing-cert.sh" "${DEV_NAME}"

# --- 2. 金庫 ---
say "2/4 金庫を作る（${VAULT}）"
echo "金庫のパスワードを新しく決めて、2 回入れてください。"
echo "・Mac のログインパスワードとは別にする"
echo "・長く強いものにして、パスワード管理アプリにしまう（忘れると、金庫を開けられなくなる）"
security create-keychain "${VAULT}"
# 眠ったときに自動で閉める（「5 分使わないと閉める」は付けない。make dist のビルドの途中で閉まり、
# 署名で止まるため。開けるのは make dist・make publish の間だけで、最後に必ず閉める）
security set-keychain-settings -l "${VAULT}"

# --- 3. 配る版用の印鑑 ---
say "3/4 配る版用の印鑑「${REL_NAME}」を作って、金庫に入れる"
make_cert "${REL_NAME}" "${WORK}/release"
/usr/bin/openssl pkcs12 -export -name "${REL_NAME}" -inkey "${WORK}/release.key.pem" \
  -in "${WORK}/release.cert.pem" -out "${WORK}/release-import.p12" -passout pass:import
security import "${WORK}/release-import.p12" -k "${VAULT}" -P import -T /usr/bin/codesign >/dev/null
echo "codesign が金庫の印鑑を使えるように設定します。金庫のパスワードを入れてください。"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s "${VAULT}" >/dev/null
echo "（Mac の画面に、ログインパスワードを聞く画面が出たら、入れて「設定をアップデート」を押してください）"
security add-trusted-cert -r trustRoot -p codeSign -k "${VAULT}" "${WORK}/release.cert.pem"
REL_SHA="$(sha1_of "${WORK}/release.cert.pem")"

mkdir -m 700 "${BACKUP}"
echo
echo "配る版用の印鑑の控え（.p12）を書き出します。控えのパスワードを新しく決めて、2 回入れてください。"
/usr/bin/openssl pkcs12 -export -name "${REL_NAME}" -inkey "${WORK}/release.key.pem" \
  -in "${WORK}/release.cert.pem" -out "${BACKUP}/nexy-release-signing.p12"

# --- 4. 更新の鍵 ---
say "4/4 更新の鍵（Sparkle）を作って、金庫に入れる"
# Sparkle の道具は、鍵を「いつもの箱」（既定のキーチェーン）に入れ、検索リストから探すので、
# 作る間だけ、金庫をいつもの箱にして、検索リストにも入れる（終わったら元に戻す）
security list-keychains -d user -s "${ORIG_LIST[@]}" "${VAULT}"
security default-keychain -d user -s "${VAULT}"
"${BIN}/generate_keys" --account "${SPARKLE_ACCOUNT}" >/dev/null
security default-keychain -d user -s "${ORIG_DEFAULT}"
SPARKLE_PUBLIC="$("${BIN}/generate_keys" --account "${SPARKLE_ACCOUNT}" -p)"
"${BIN}/generate_keys" --account "${SPARKLE_ACCOUNT}" -x "${BACKUP}/nexy-release-sparkle-key.txt" >/dev/null
chmod 600 "${BACKUP}"/*
security list-keychains -d user -s "${ORIG_LIST[@]}"
security lock-keychain "${VAULT}"

DEV_SHA="$(security find-identity -v -p codesigning "${LOGIN}" | grep -F "\"${DEV_NAME}\"" | awk '{print $2}' | head -1)"

say "できました（ここから下は、公開してよい情報です。AI に貼ってください）"
cat <<EOF
開発用の印鑑   ${DEV_NAME}    SHA-1: ${DEV_SHA}
配る版用の印鑑 ${REL_NAME}  SHA-1: ${REL_SHA}
更新の鍵の公開側（SUPublicEDKey）: ${SPARKLE_PUBLIC}
金庫: ${VAULT}（閉めました。検索リストには入れていません）
EOF

say "このあと、あなたがやること（秘密の情報なので、AI には貼らないでください）"
cat <<EOF
1. 次の 2 つのファイルを、パスワード管理アプリなど Mac の外にしまう
   - ${BACKUP}/nexy-release-signing.p12（配る版用の印鑑の控え）と、その控えのパスワード
   - ${BACKUP}/nexy-release-sparkle-key.txt（更新の鍵の控え）
2. 金庫のパスワードも、パスワード管理アプリにしまう
3. しまい終えたら、フォルダ ${BACKUP} をゴミ箱に入れて、ゴミ箱を空にする
EOF
