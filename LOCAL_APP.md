# Local Nebby.app

Run from the repository root:

```sh
./Scripts/build-local-app.sh
```

The script builds the macOS Release target with local ad-hoc signing, copies it to `dist/Nebby.app`, and verifies its code signature. It requires the installed Xcode command-line tools. `DEVELOPER_DIR` may be set to select another Xcode installation. The built app is for local use on this Mac; it is not signed or notarised for distribution.

The source icon is `Design/NebbyAppIcon.svg`. The Xcode AppIcon asset catalog contains checked-in PNG renditions, so a normal Release build does not require an image-generation tool. When the source icon changes, run `./Scripts/generate-app-icon.sh` with ImageMagick available, inspect the generated PNGs, then commit the updated icon assets.

`dist/` and Xcode build intermediates are ignored by Git. Open `dist/Nebby.app` in Finder to run it, or drag it into `/Applications` if you want to install it. The build script does not touch `/Applications`.
