# media/

Screenshots and assets for the CyberCord landing README.

## Layout

```
media/
├── screenshots/          # Feature captures used in README
│   ├── app-lobby.jpg         # Main workspace: rooms, voice, chat, members (HERO)
│   ├── app-claim.jpg         # First-run owner claim form
│   ├── app-servers.jpg       # Desktop client server picker and connection controls
│   ├── app-screenshare.jpg   # Live screen share / media stage
│   ├── app-server.jpg        # Server overview dashboard (owner/admin)
│   ├── app-invite.jpg        # Invite links + member management
│   ├── app-audio.jpg         # Voice/audio settings (noise suppression)
│   ├── app-privacy.jpg       # Room settings: dissolving chat / auto-purge
│   └── app-profile.jpg       # Profile & account settings
├── releases/             # Placeholder only; binaries belong on GitHub Releases
└── icons/                # App icon, favicons, badges
```

## Conventions

- Screenshots: JPG/PNG, dark UI with neon-green accent, capture at 2x Retina.
- Filenames: kebab-case describing feature — `app-<feature>.jpg`.
- Desktop installers and container archives are release artifacts, not Git content. Publish them through GitHub Releases/GHCR and keep `media/releases/` empty except for `.gitkeep`.

## Publication status

- [x] Capture screenshots (9 in place, indexed above)
- [x] Publish desktop client binaries as GitHub Release assets rather than committing them
- [x] Confirm license text for README (MIT — free to use at own risk)
- [x] Confirm public server image: `ghcr.io/ramborogers/cybercord-server`
