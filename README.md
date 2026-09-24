# Nebby

A selection-aware Get Info concept for macOS.

Finder's Get Info is centred on individual files. Invoking it for many selected items opens separate windows; Summary Info and Finder's Inspector show only parts of the collection. Nebby explores a different question: **What is true of this selection?** It treats the selection itself as one inspectable object while keeping its members available for closer inspection.

## The interaction

Nebby opens as a compact inspector with an aggregate General section and a collapsed Items section. Expanding Items widens the window and reveals a native file table with name, kind, size, dimensions and modification date. File icons come from macOS. Selecting a row, a range or a discontiguous set changes the information shown in General.

The **parent selection** is the set of files supplied through Open or a Finder drag. The **inspection scope** is the set currently examined inside Nebby. Row selection changes only that local scope; the parent selection and window identity remain intact. A one-item scope shows that item's values, while a subset recomputes aggregates for its members. **All N Items** returns to the full parent selection. Clearing table selection also restores the full scope. Replacing the input resets the local scope.

<!-- Insert a verified capture of the compact running app here. -->
<!-- Insert verified captures of the expanded table and a local subset scope here. -->

## Information that keeps its meaning

Nebby preserves individual, shared, mixed and aggregate values. It also distinguishes a field that applies to only some objects from a field that applies but could not be read. For example, a tag can be present on every item in the current scope, some items or none. Image dimensions can apply to only the images in a mixed file selection; unreadable dimensions for one of those images are a different state from dimensions being inapplicable to a folder.

The Tags section demonstrates scope-aware editing with native checked, indeterminate and unchecked controls. These tag changes are held in local prototype state; they do not modify Finder tags. The Sharing & Permissions section demonstrates a controlled partial-failure operation and does not change filesystem permissions. Its rule is **successful changes persist**: unresolved items remain visible, and Retry targets only those items. Dismiss closes the report without rolling back successes.

## Design principles

- One selection, one information surface.
- Shared, aggregate and mixed values retain distinct meanings.
- Inspect a member or subset without losing parent context.
- Bulk edits operate on an explicit inspection scope.
- Successful changes survive partial failure.

## Native implementation

`FileInputController` accepts Open-panel and dropped-file input. `ParentSelection` owns the original URLs and loads immutable `FileItem` records through `FileMetadataReader`. The reader uses `URLResourceValues` for file facts and ImageIO for image dimensions. `InspectionScope` tracks stable item identities independently from the parent. `SelectionAggregator` derives `AggregateSelection` from exactly the items in the active scope; presentation code formats those results without duplicating aggregation rules.

SwiftUI provides the inspector and disclosure layout. An AppKit `NSTableView` provides desktop row selection and keyboard behaviour. `NSOpenPanel` handles Open; `NSWorkspace` supplies native file icons. The controlled tag and partial-failure state machines remain separate from the views.

## Build and test

The project targets **macOS 27.0** and was built with **Xcode 27.0**. The Xcode project sets Swift language version 5.0. An installed Xcode, rather than only Command Line Tools, is required for the commands below.

```sh
git clone https://github.com/scapintobias/nebby.git
cd nebby
open Nebby.xcodeproj
```

Build the Debug app and run the full test suite from the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nebby.xcodeproj -scheme Nebby -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NebbyDebugDerivedData \
  CODE_SIGNING_ALLOWED=NO build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Nebby.xcodeproj -scheme Nebby -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/NebbyTestDerivedData \
  CODE_SIGNING_ALLOWED=NO test
```

The 43 tests cover file metadata extraction, folders, symbolic links, image dimensions and corrupt metadata; aggregate meaning and incomplete applicability; inspection scope; mixed tag state; and partial-failure recovery. The test suite uses local fixtures and deterministic operation state.

## Local app

Run `./Scripts/build-local-app.sh` to produce an ad-hoc signed Release build at `dist/Nebby.app`. It can be opened locally in Finder. [LOCAL_APP.md](LOCAL_APP.md) explains the script and icon-source workflow. `dist/` and Xcode build intermediates are excluded from Git. This local build is distinct from signed and notarised public distribution; no public release package is provided.

## Status and origin

Nebby is a native macOS interaction-design prototype, not a Finder replacement. It does not intercept Finder's ⌘I command. The current tag and permission interactions are controlled demonstrations; they leave user files unchanged. There is no public signing or notarisation. Open-panel selection and Finder drag input can differ for symbolic links because they use different macOS input paths.

The premise came from a small macOS irritation: selecting many Finder items and pressing ⌘I creates one Get Info window for every item. Nebby explores what changes when the selection, rather than each individual file, becomes the primary object of inspection.
