#!/bin/bash

# Dynamically detect user's home directory and build .env path
ENV_FILE="$HOME/.gradle/.env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env file not found at $ENV_FILE"
  exit 1
fi

# Export variables from .env file
# shellcheck disable=SC2046
export $(grep -v '^#' "$ENV_FILE" | xargs)

# Verify required variables
REQUIRED_VARS=(DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD)
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing required variable: $var"
    exit 1
  fi
done


# shellcheck disable=SC2012
WAR_FILE=$(ls customer_service/build/libs/*.war | head -n 1)

if [ -z "$WAR_FILE" ]; then
  echo "No WAR file found, building..."
  ./gradlew :customer_service:build
  # shellcheck disable=SC2012
  echo "Build succeeds"
  # shellcheck disable=SC2012
  WAR_FILE=$(ls customer_service/build/libs/*.war | head -n 1)
fi

# Run Spring Boot app with proper system properties
# Find and try each WAR file until one succeeds
# shellcheck disable=SC2045
for WAR_PATH in $(ls -t customer_service/build/libs/*.war); do
  echo "  🚀 Attempting to start Spring Boot application with: $WAR_PATH"
  java \
    -Dspring.datasource.url="jdbc:${DB_TYPE}://${DB_HOST}:${DB_PORT}/${DB_NAME}" \
    -Dspring.datasource.username="$DB_USER" \
    -Dspring.datasource.password="$DB_PASSWORD" \
    ${SPRING_PROFILES_ACTIVE:+-Dspring.profiles.active="$SPRING_PROFILES_ACTIVE"} \
    -jar "$WAR_PATH" && break

  echo "  ❌ Failed to start with: $WAR_PATH, trying next..."
done