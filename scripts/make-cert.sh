#!/bin/zsh
# Cria um certificado autoassinado "NumpadDeck Dev" no seu Keychain de login.
# Com ele, a permissão de Acessibilidade sobrevive a rebuilds (a assinatura ad hoc muda a cada build).
# Roda uma vez. Pode pedir a senha do usuário para confiar no certificado.
set -e
T=$(mktemp -d)
cat > "$T/cert.cnf" <<'CNF'
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=NumpadDeck Dev
[ext]
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
basicConstraints=critical,CA:false
CNF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout "$T/key.pem" -out "$T/cert.pem" -config "$T/cert.cnf" >/dev/null 2>&1
openssl pkcs12 -export -inkey "$T/key.pem" -in "$T/cert.pem" -out "$T/dev.p12" -passout pass:np -legacy >/dev/null 2>&1
security import "$T/dev.p12" -k ~/Library/Keychains/login.keychain-db -P np -T /usr/bin/codesign
security add-trusted-cert -p codeSign -k ~/Library/Keychains/login.keychain-db "$T/cert.pem"
rm -rf "$T"
security find-identity -v -p codesigning | grep "NumpadDeck Dev" && echo "OK: agora rode ./scripts/build.sh"
