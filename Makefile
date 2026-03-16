# ─────────────────────────────────────────────
#  Sahayi Android — Release Makefile
#  Usage: make release
# ─────────────────────────────────────────────

# ── Config ────────────────────────────────────
GITHUB_REPO   := multiplexintl/sahayi_android
PUBSPEC       := pubspec.yaml
APK_SRC       := build/app/outputs/flutter-apk/app-release.apk
APK_ASSET     = sahayi_v$(VERSION_NAME).apk
VERSION_JSON  := version.json

# ── Read version from pubspec.yaml ────────────
# Extracts the "version: X.Y.Z+N" line
RAW_VERSION   := $(shell grep '^version:' $(PUBSPEC) | awk '{print $$2}')
VERSION_NAME  := $(shell echo "$(RAW_VERSION)" | cut -d'+' -f1)
VERSION_CODE  := $(shell echo "$(RAW_VERSION)" | cut -d'+' -f2)
TAG           := v$(VERSION_NAME)

# ── GitHub token (read from env or ~/.sahayi_token) ──
GITHUB_TOKEN  ?= $(shell cat ~/.sahayi_token 2>/dev/null)

# ─────────────────────────────────────────────
.PHONY: release check-token

release: check-token
	@echo ""
	@echo "╔══════════════════════════════════════╗"
	@echo "║  Sahayi Release: $(TAG) (build $(VERSION_CODE))  ║"
	@echo "╚══════════════════════════════════════╝"
	@echo ""

	@echo "▶  1/5  flutter clean..."
	@flutter clean

	@echo "▶  2/5  flutter pub get..."
	@flutter pub get

	@echo "▶  3/5  Building release APK..."
	@flutter build apk --release
	@echo "✔  APK built: $(APK_SRC)"

	@echo "▶  4/5  Updating $(VERSION_JSON)..."
	@printf '{\n  "versionCode": $(VERSION_CODE),\n  "versionName": "$(VERSION_NAME)",\n  "apkName": "$(APK_ASSET)",\n  "notes": "Release $(TAG)"\n}\n' > $(VERSION_JSON)
	@echo "✔  $(VERSION_JSON) updated"

	@echo "▶  5/5  Uploading to GitHub Releases ($(TAG))..."
	@$(MAKE) _github_upload

	@echo ""
	@echo "✅  Done! Release $(TAG) is live."
	@echo "    https://github.com/$(GITHUB_REPO)/releases/tag/$(TAG)"
	@echo ""

# ── Internal: create release + upload assets ──
_github_upload:
	@# Delete existing release for this tag if it exists (allows re-releasing same version)
	@EXISTING=$$(curl -sf \
		-H "Authorization: Bearer $(GITHUB_TOKEN)" \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/$(GITHUB_REPO)/releases/tags/$(TAG)" \
		| jq -r '.id // empty'); \
	if [ -n "$$EXISTING" ]; then \
		echo "   Deleting existing release $$EXISTING..."; \
		curl -sf -X DELETE \
			-H "Authorization: Bearer $(GITHUB_TOKEN)" \
			-H "Accept: application/vnd.github+json" \
			"https://api.github.com/repos/$(GITHUB_REPO)/releases/$$EXISTING" > /dev/null; \
	fi
	@# Delete the git tag remotely too (so we can recreate it)
	@curl -sf -X DELETE \
		-H "Authorization: Bearer $(GITHUB_TOKEN)" \
		-H "Accept: application/vnd.github+json" \
		"https://api.github.com/repos/$(GITHUB_REPO)/git/refs/tags/$(TAG)" > /dev/null 2>&1 || true

	@# Create a new release (this also creates the tag)
	@RELEASE_ID=$$(curl -sf -X POST \
		-H "Authorization: Bearer $(GITHUB_TOKEN)" \
		-H "Accept: application/vnd.github+json" \
		-H "Content-Type: application/json" \
		"https://api.github.com/repos/$(GITHUB_REPO)/releases" \
		-d '{"tag_name":"$(TAG)","name":"$(TAG)","body":"Release $(TAG) — build $(VERSION_CODE)","draft":false,"prerelease":false}' \
		| jq -r '.id'); \
	if [ -z "$$RELEASE_ID" ] || [ "$$RELEASE_ID" = "null" ]; then \
		echo "❌  Failed to create GitHub release. Check your token and repo access."; \
		exit 1; \
	fi; \
	echo "   Release created (id: $$RELEASE_ID)"; \
	\
	echo "   Uploading $(APK_ASSET)..."; \
	curl -sf -X POST \
		-H "Authorization: Bearer $(GITHUB_TOKEN)" \
		-H "Accept: application/vnd.github+json" \
		-H "Content-Type: application/vnd.android.package-archive" \
		"https://uploads.github.com/repos/$(GITHUB_REPO)/releases/$$RELEASE_ID/assets?name=$(APK_ASSET)" \
		--data-binary @$(APK_SRC) > /dev/null; \
	echo "   ✔  $(APK_ASSET) uploaded"; \
	\
	echo "   Uploading sahayi.apk (NFC stable alias)..."; \
	curl -sf -X POST \
		-H "Authorization: Bearer $(GITHUB_TOKEN)" \
		-H "Accept: application/vnd.github+json" \
		-H "Content-Type: application/vnd.android.package-archive" \
		"https://uploads.github.com/repos/$(GITHUB_REPO)/releases/$$RELEASE_ID/assets?name=sahayi.apk" \
		--data-binary @$(APK_SRC) > /dev/null; \
	echo "   ✔  sahayi.apk (alias) uploaded"; \
	\
	echo "   Uploading $(VERSION_JSON)..."; \
	curl -sf -X POST \
		-H "Authorization: Bearer $(GITHUB_TOKEN)" \
		-H "Accept: application/vnd.github+json" \
		-H "Content-Type: application/json" \
		"https://uploads.github.com/repos/$(GITHUB_REPO)/releases/$$RELEASE_ID/assets?name=$(VERSION_JSON)" \
		--data-binary @$(VERSION_JSON) > /dev/null; \
	echo "   ✔  $(VERSION_JSON) uploaded"

check-token:
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo ""; \
		echo "❌  GitHub token not found."; \
		echo "    Save your token to ~/.sahayi_token:"; \
		echo "    echo 'ghp_yourtoken' > ~/.sahayi_token"; \
		echo "    chmod 600 ~/.sahayi_token"; \
		echo ""; \
		exit 1; \
	fi
