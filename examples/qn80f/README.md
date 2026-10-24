# QN80F example layout and app list

The Home layout and app catalog used on the QE55QN80FAUXXH
(firmware T-PTMFDEUC-0090-1301.0) described in the main README:

- Dark theme, 24-hour clock with the date (`HH:mm · dd.MM.yy`).
- Wide card: PlayStation 5 on HDMI 4 (source 16), with a PlayStation-symbols image.
- Portrait cards: HBO Max and Oneplay.
- Dock: HBO Max, Oneplay, YouTube, PlayStation 5, Disney+, Your Apps.
- Microphone key opens Spotify (`VoiceKey`).
- Apps: Netflix, YouTube, Prime Video, HBO Max, Disney+, Oneplay, Spotify.

App IDs and HDMI source numbers come from that TV. Check them against your
own inventory and Probe output before using this on another TV or region.

## Use it

```sh
cp examples/qn80f/home.local.json launcher/assets/home.local.json
cp examples/qn80f/apps.local.json launcher/assets/apps.local.json
```

Both destinations are gitignored, so your edits stay private. Then fetch the
publisher artwork, which is not redistributed in this repository
(see [docs/06-artwork.md](../../docs/06-artwork.md)):

```sh
.venv/bin/python tools/fetch_artwork.py --app Netflix --app YouTube \
  --app 'Prime Video' --app 'HBO Max' --app 'Disney+' --app Spotify
```

Two images have no download source and are not included:

| File in `launcher/assets/app-icons/` | Used for | If you do not have it |
|---|---|---|
| `oneplay.png` | Oneplay card (1200×630 was used) | Set Oneplay's `Asset` to a file in `placeholders/` |
| `ps5-symbols.png` | Icon on the wide PS5 card (transparent PNG) | Remove the `Icon` line; the backdrop still shows |

Validate before building, then build and install as in
[docs/04-launcher.md](../../docs/04-launcher.md):

```sh
dotnet run --project tests/CatalogTests.csproj -- \
  launcher/assets/apps.local.json launcher/assets/home.local.json
```
