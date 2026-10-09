# Mobile controls and menus

The existing Godot game now has touch controls, responsive interfaces and a browser export. These are implemented in the canonical `WILDBOUND_v0.4.0-3D-dev` project. Mobile gameplay is landscape-only. A native phone package has not been exported.

## Try the controls on this computer

Double-click **Play Wildbound Mobile Preview.cmd** in the parent `wildbound game` folder. Drag the left pad with the mouse and click the action buttons. Resizing to portrait pauses the game and displays a rotate-phone notice; returning to landscape resumes it. This launcher uses the normal game save; the automated tests use separate fixture saves.

The preview forces touch mode for that run without saving the setting. In the regular game, **Menu → Touch Controls** offers **Auto**, **On** and **Off**. Auto enables the controls on Android, iOS or a touchscreen detected by Godot. Selecting a mode in the regular game saves it in `user://interface.cfg`.

## Play with touch

| Control | Behavior |
| --- | --- |
| Left pad | Analog movement; a small drag walks slowly |
| Interact | Gather, talk, rest or deliberately search grass |
| Jump / Rise | Jump on foot; hold to rise in flight |
| Sprint | Toggle sprint, gallop or faster flight; tap again to stop |
| Ride / Dismount | Use an owned, conscious land companion with a saddle |
| Fly / Land | Use an owned, conscious Vulturon with a flight harness |
| Descend | Hold to lower flight altitude |
| Camera | Switch camera view while on the ground |
| Camp / Friends / Pack / Menu | Open the existing game interfaces |
| Rotate / Place / Cancel | Position a selected building from Camp |
| Continue | Advance NPC dialogue |

Movement and action buttons own separate fingers, so steering and jumping or rising work together. Sprint is a toggle so two thumbs can steer and jump. Menus, dialogue, scene changes, focus loss and orientation changes release held gameplay input. Battle command and selection buttons use the existing combat callbacks.

## Layout behavior

Landscape play uses a 960 × 540 logical canvas. The canvas expands for different screen shapes, and native mobile builds use Godot's reported safe area. Gameplay controls are at the bottom corners. At the tested 844 × 390 window size, gameplay targets exceed 44 physical pixels and menu targets are at least 64 logical pixels tall. A portrait layout remains available internally for a readable rotate-phone notice, but gameplay and menus are paused behind it.

Camp, Friends, backpack, reserve, system menu and battle choices adapt to the available width. Long lists and NPC text scroll. Selection and typed Friends fields survive rotation. Close, Resume and confirmation controls remain accessible. The desktop layout and keyboard behavior remain available when touch controls are off.

## Verification

Tests dispatch real `InputEventScreenTouch` events through the actual Godot controls, and rendered runs capture the actual game viewport. They run with isolated application data and save fixtures.

| Suite | Headless | Rendered | Scope |
| --- | --- | --- | --- |
| Mobile acceptance | 60 passed | 68 passed | Bootstrap, two-finger movement/jump, analog walking, sprint, gather/save round-trip, landscape menus/dialogue, validated building placement, riding, flight, focus cleanup, portrait pause/input blocking and landscape resume |
| Mobile menus | 31 passed | 40 passed | Six party members, reserve lists, real swap/item effects, scrolling, rotation and system menu callbacks |
| Mobile battle | 34 passed | 37 passed | Landscape/portrait command layout, retained battle selection flows and faint choices |

Rendered counts include screenshot assertions. Logs and images are under `.qa`. See [tests/README.md](../tests/README.md) and [tests/MOBILE_MENU_TEST.md](../tests/MOBILE_MENU_TEST.md) for commands.

Desktop regressions were also rerun: 166 existing, 63 homestead, 47 structure/physics, 62 movement, 34 battle mechanics, 104 travel, 24 battle exit, 39 headless / 41 rendered encounter pacing, 12 rendered battle visual, 19 save recovery and 48 network-state checks. The actual two-process ENet Host/Join, battle and trade check passed with solo saves preserved. The rendered adventure/save/reopen check is recorded separately in the tests README.

These results establish engine input behavior and phone-sized layouts on Windows. Independent menu and battle fixtures can still exercise portrait layout geometry without attaching an actual game session; the real Bootstrap acceptance test enforces landscape-only play. Physical phone performance, Safari audio and browser safe areas still need a device test. Godot's native touch-scrolling path cannot be fully exercised with the desktop display server.

## Browser build

`export_presets.cfg` writes a single-threaded WebGL 2 compatibility export into `../sites/wildbound-play/dist`. Run `python tools/prepare_web_site.py` after export. This compresses the official engine to 10,054,758 bytes, verifies decompression matches the original, and records hashes in the Site checkout's `build-info.json`. The compressed engine and approximately 7.3 MB game pack stay below the host's per-file limit. The launch page decompresses WebAssembly through the modern browser's DecompressionStream API.

The browser launch screen requires landscape before play; rotating upright also pauses the Godot scene tree and releases input. The home-screen manifest requests landscape. Full-screen mode requests an orientation lock where supported; the rotate screen provides the fallback when a browser cannot lock orientation.

Solo progress is stored in IndexedDB on the current browser origin. The existing temporary-file and backup-save behavior is preserved. Packaged item discovery handles Godot's `.tres.remap` resources. Browser QA confirmed gathered wood and starter inventory reached IndexedDB. Device-to-device sync and online accounts are not included.

The current multiplayer transport is ENet/UDP; the browser version needs a browser-compatible transport/service before Friends can support online sessions. The Friends interface explains this limitation in web builds. Sites identity and exact published artifacts are retained separately in the `sites/wildbound-play` checkout.
