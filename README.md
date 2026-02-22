# Meme Creator

Fetch structured data from a server asynchronously.

## Overview

Welcome to the Meme Creator app, where you’ll learn to fetch data from the internet to create panda memes.

To create a meme, you’ll load some images from a URL, which could take some time depending on the speed of your internet connection to the server. You’ll use an asynchronous request so that your app can keep doing other things in the background, like responding to user actions, while waiting for the images to load into the UI.

In this walkthrough, you’ll learn how asynchronous data fetching works, and how to use it when retrieving panda images and their corresponding data in JSON format.

## Tutorial

[View a tutorial on this sample.](doc://com.apple.documentation/tutorials/sample-apps/MemeCreator)

## Running the Sample Code Project

Before running this sample on a physical device, select a Development Team under the Signing & Capabilities section in the project editor.

You can now open the project directly in Xcode using `MemeCreator.xcodeproj`.

## App Guide (Current Build)

This app is now a full meme editor experience with persistence, sharing, and template browsing.

### Main Tabs

- **Editor**
  - Create memes over panda templates or imported photos.
  - Add multiple text layers.
  - Move text layers by selecting move mode and dragging on canvas.
  - Customize font, size, fill color, and stroke color.
  - Shuffle template, import image, add text, hide/show controls, reset editor.
  - Save meme to Photos and SwiftData gallery.
  - Share generated meme through system share sheet.

- **Templates**
  - Browse available panda templates from API.
  - Select active template for editing.
  - Includes loading and retry states.

- **My Memes**
  - Shows saved memes from SwiftData.
  - Open meme detail view.
  - Share, copy to clipboard, save to Photos, delete.

### Onboarding

- 4 pages explaining main app capabilities.
- Can be skipped.
- Persisted with `@AppStorage` so it only appears once.

## What's New

- Added native Xcode project support (`MemeCreator.xcodeproj`).
- Added robust save flow handling:
  - Save-to-Photos completion callbacks with error reporting.
  - Explicit SwiftData saves with error handling.
- Fixed SwiftUI ambiguity hotspots in dynamic list/ForEach sections.
- Improved model identity stability for template rendering (`Panda.id`).
- Added DEBUG console logs across important flows (fetch, onboarding, editor actions, save/share/delete paths).

## Technical Notes

- Minimum iOS target: **17.0**.
- Data persistence: **SwiftData** (`SavedMeme` with external storage for image blobs).
- API endpoint used by templates:
  - `http://playgrounds-cdn.apple.com/assets/pandaData.json`
- Important network detail:
  - The source returns image URLs with `https://`, but the image host needs `http://` in this environment; URL normalization is handled in fetcher.

## Test Checklist

Use this checklist after opening `MemeCreator.xcodeproj`:

1. **Launch + Onboarding**
   - First launch shows onboarding.
   - Next/Skip complete onboarding.
   - Relaunch app and verify onboarding is not shown again.

2. **Templates**
   - Open Templates tab and verify images load.
   - Trigger retry flow by disabling/enabling network.
   - Tap different templates and verify selection state updates.

3. **Editor Base Flow**
   - Add at least 2 text layers.
   - Edit text, font, size, fill/stroke colors.
   - Move text layer in canvas (enter move mode + drag gesture).
   - Toggle controls visibility.
   - Reset editor and verify state is clean.

4. **Import + Share**
   - Import photo from library.
   - Share meme and verify share sheet opens.

5. **Save Flow**
   - Save meme from editor.
   - Confirm success overlay appears.
   - Verify meme appears in My Memes.
   - Verify image is saved to Photos.

6. **Gallery Detail Flow**
   - Open a saved meme.
   - Test Share, Copy, Save to Photos, Delete.
   - Verify delete confirmation and removal from grid.

7. **Orientation + Layout**
   - Test portrait and landscape.
   - Verify editor remains usable in both layouts.

8. **Accessibility Spot Check**
   - VoiceOver labels for key buttons (save/share/import/add text/reset).
   - Slider announces font size value.

9. **Console Debug Logs (DEBUG builds)**
   - Verify logs appear with prefix `[MemeCreator]`.
   - Check logs for fetch, import, share, save, delete events.

## Known Setup Requirements

- Configure Signing Team in Xcode for device runs.
- Grant Photo Library permissions when prompted.
