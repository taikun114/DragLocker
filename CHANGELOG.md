# DragLocker Changelog
**English** | [日本語](docs/CHANGELOG-ja.md)

<!--
The order of listing is as follows:
- New Features
- Bug Fixes and Improvements

Each section lists items in the following order:
- Notable Information
- Support
- Additions
- Fixes
- Improvements
- Changes
- Removals

Notes
- Make the first level of the list bold
- Make links bold
- When linking to Issues, Pull Requests, or Discussions, include the full URL
-->

## 1.0.1
### New Features
- **Add "Do Not Lock on Software Clicks" setting to General settings**
  - Prevents drag lock from activating on clicks made by remote access tools such as Screen Sharing.
  - For example, when drag lock is enabled on both the remote client and the remote host, this setting prevents drag lock from being triggered on both devices simultaneously (delegating drag lock to the client device).

### Bug Fixes and Improvements
- **Add system overlay settings for macOS Golden Gate**
- **Add pointer image for macOS Golden Gate**
- **Fix issue where a click could occur when releasing drag lock in some apps**
  - Releasing drag lock in screen sharing apps or virtual machines no longer triggers an unintended click.
  - Due to this fix, the timing for releasing drag lock has changed from the moment the second mouse button is **pressed** to the moment it is **released**. This may have a slight impact on usability.
- **Fix issue where per-app settings were not applied in some apps (such as Java apps)**
- **Improve tracking responsiveness of the icon displayed near the pointer**
- **Improve the appearance of the license screen**

## 1.0.0
Initial Release!

