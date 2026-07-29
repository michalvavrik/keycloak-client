#!/bin/bash -e

function echo_header() {
  echo ""
  echo "======================================================================="
  echo "$1"
  echo "-----------------------------------------------------------------------"
  echo ""
}

function error() {
  echo "======================================================================="
  echo "Error"
  echo "-----------------------------------------------------------------------"
  echo "$1"
  echo ""
  exit 1
}

function syncFiles() {
  MODULE=$1;
  echo_header "Syncing files in the module $MODULE";
  cd $MODULE

  # Remove the existing files before sync
  rm -rf src/main/java/*
  rm -rf src/main/resources/*

  mvn clean install -Psync
  mv target/unpacked/* src/main/java/

  if  [ -d target/unpacked-resources -a ! -z "$(ls -A target/unpacked-resources/* 2>/dev/null)" ]
  then
    mv target/unpacked-resources/* src/main/resources/
  fi
  cd ..
}

# Check if inside keycloak-client directory
if [[ ! $PWD == *keycloak-client ]]; then
  error "The script is supposed to be executed in the root of 'keycloak-client' repository";
fi;

syncFiles client-common-synced

# The Keycloak server uses RawJsonValue (a Jackson-version-agnostic wrapper) in some
# representation classes. The keycloak-client publishes a Jackson 2-only artifact,
# so we restore the original JsonNode type to preserve backward compatibility.
echo_header "Restoring JsonNode API in client representations"
cd client-common-synced/src/main/java
for f in \
  org/keycloak/representations/idm/ClientPolicyExecutorRepresentation.java \
  org/keycloak/representations/idm/ClientPolicyConditionRepresentation.java \
  org/keycloak/representations/idm/ClientPoliciesRepresentation.java \
  org/keycloak/representations/idm/ClientProfilesRepresentation.java \
  org/keycloak/representations/idm/RealmRepresentation.java; do
  if grep -q 'RawJsonValue' "$f" 2>/dev/null; then
    sed -i 's/import org.keycloak.json.RawJsonValue;/import com.fasterxml.jackson.databind.JsonNode;/' "$f"
    sed -i 's/import org.keycloak.json.KeycloakJsonMapperFactory;/import org.keycloak.util.JsonSerialization;/' "$f"
    sed -i 's/RawJsonValue/JsonNode/g' "$f"
    sed -i 's/KeycloakJsonMapperFactory\.mapper()/JsonSerialization.mapper/g' "$f"
  fi
done
cd ../../../..

syncFiles admin-client
syncFiles authz-client
