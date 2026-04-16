# Web Build

This project is packaged for browser play with `love.js` 11.5.

## Build

Run:

```bash
./scripts/build-web.sh
```

That produces:

* `build/cgw2026_2.love`
* `build/cgw2026_2-itch-web.zip`

The ZIP is the artifact to upload to itch as an HTML game.

## Itch Settings

Use these settings on the itch project page:

* Kind of game: `HTML`
* Launch mode: `Embed in page`
* Viewport: `1280 x 720`
* Mobile friendly: off until the browser build is tested on touch devices

`love.js` expects cross-origin isolation headers for best compatibility. The build includes the upstream `.htaccess`, which helps on Apache-style hosting, but itch may still behave differently. Test the uploaded page on itch before relying on it as the only distribution channel.

## Packaging Notes

The build excludes `full_map_hexagons.png` because it is not referenced by the game and adds roughly 30 MB to the browser payload.
