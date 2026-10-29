# Mobile controls and menus

The shared Godot game has contextual touch controls, responsive menus and an Android RC1 debug APK in `builds/WILDBOUND_Mobile_RC1_Debug.apk`. Mobile gameplay supports portrait and landscape. The APK has not been tested on a real phone. See [the RC1 report](MOBILE_IMPLEMENTATION_REPORT.md) for build provenance and evidence.

## Try the controls on this computer

Double-click **Play Wildbound Mobile Preview.cmd** in the parent `wildbound game` folder. Drag the left pad with the mouse and click the action buttons. Resize between portrait and landscape to preview both layouts. Rotation keeps the game playable and releases held touches. This launcher uses the normal game save; the automated tests use separate fixture saves.

The preview forces touch mode for that run without saving the setting. In the regular game, **Menu → Touch Controls** offers **Auto**, **On** and **Off**. Auto enables the controls on Android, iOS or a touchscreen detected by Godot. Selecting a mode in the regular game saves it in `user://interface.cfg`.

## Play with touch

| Control | Behavior |
| --- | --- |
| Left pad | Analog movement; a small drag walks slowly |
| Interact | Gather, talk, rest or deliberately search grass |
| Jump / Rise | Jump on foot or while riding; hold Rise in flight |
| Sprint | Toggle sprint or gallop; tap again to stop |
| Ride / Dismount | Use an owned, conscious land companion with a saddle |
| Fly / Land | Use an owned, conscious Vulturon with a flight harness |
| Descend | Hold to lower flight altitude |
| Menu → Camera View | Switch the existing automatic camera view |
| Menu | Open Backpack, Camp & Build, Friends or Save & Settings |
| Placement pad | Move a selected building's target while the keeper stays still |
| Rotate / Place / Cancel | Rotate, confirm or cancel the construction preview |
| Undo | Refund the latest placement within 12 seconds if no dependent progress changed |
| Continue | Advance NPC dialogue |

Only relevant actions appear. Flight shows Rise, Descend and Land; unsafe landing disables Land and shows feedback. Movement and action buttons own separate fingers, so steering and jumping or rising work together. Sprint is a toggle. Menus, dialogue, scene changes, focus loss, suspension and orientation changes release held input. Battle uses the existing combat callbacks. Android Back closes the active menu or opens Settings from exploration.

In Save & Settings, scroll to adjust joystick deadzone, graphics quality and camera follow response. Low/Medium target 30 FPS; High caps at 60. These caps are not measured phone performance. The camera follows automatically; drag orbit, pinch and inversion are not included.

## Layout behavior

Landscape play uses a 960 × 540 logical canvas. The canvas expands for different screen shapes, and native mobile builds use Godot's reported safe area. Gameplay controls are at the bottom corners. At the tested 844 × 390 window size, gameplay targets exceed 44 physical pixels and menu targets are at least 64 logical pixels tall. Portrait play uses a 540 × 960 logical canvas, with an extra-tall viewport on taller phones. Thumb actions use two columns; menus and dossiers stack to fit. Neither orientation pauses gameplay.

Camp, Friends, backpack, reserve, system menu and battle choices adapt to the available width. Long lists and NPC text scroll. Selection and typed Friends fields survive rotation. Close, Resume and confirmation controls remain accessible. The desktop layout and keyboard behavior remain available when touch controls are off.

## Verification

Tests dispatch real `InputEventScreenTouch` events through the actual Godot controls, and rendered runs capture the actual game viewport. They run with isolated application data and save fixtures.

| Suite | Headless | Rendered | Scope |
| --- | --- | --- | --- |
| Mobile acceptance | 55 passed | 63 passed | Bootstrap, two-finger movement/jump, analog walking, sprint, gather/save round-trip, landscape menus/dialogue, validated building placement, riding, flight, focus cleanup, portrait play and safe rotation |
| Mobile menus | 44 passed | 53 passed | Six compact party cards, detail navigation, reserve lists, real swap/item effects, scrolling, rotation and system menu callbacks |
| Mobile battle | 34 passed | 37 passed | Landscape/portrait command layout, retained battle selection flows and faint choices |

Rendered counts include screenshot assertions. Logs and images are under `.qa`. See [tests/README.md](../tests/README.md) and [tests/MOBILE_MENU_TEST.md](../tests/MOBILE_MENU_TEST.md) for commands.

Desktop regressions were also rerun: 166 existing, 63 homestead, 47 structure/physics, 62 movement, 34 battle mechanics, 104 travel, 24 battle exit, 39 headless / 41 rendered encounter pacing, 12 rendered battle visual, 19 save recovery and 48 network-state checks. The actual two-process ENet Host/Join, battle and trade check passed with solo saves preserved. The rendered adventure/save/reopen check is recorded separately in the tests README.

These results establish engine input behavior and phone-sized layouts on Windows. Independent menu and battle fixtures can still exercise portrait layout geometry without attaching an actual game session; the real Bootstrap acceptance test enforces landscape-only play. Physical phone performance, Safari audio and browser safe areas still need a device test. Godot's native touch-scrolling path cannot be fully exercised with the desktop display server.

## Browser build

The public browser preview is the earlier mobile build. It has not been refreshed with Android RC1; deployment and hosted gameplay verification are separate evidence levels, recorded in the RC1 report.

`export_presets.cfg` writes a single-threaded WebGL 2 compatibility export into `../sites/wildbound-play/dist`. Run `python tools/prepare_web_site.py` after export. This compresses the official engine to 10,054,758 bytes, verifies decompression matches the original, and records hashes in the Site checkout's `build-info.json`. The compressed engine and approximately 7.3 MB game pack stay below the host's per-file limit. The launch page decompresses WebAssembly through the modern browser's DecompressionStream API.

The browser launch screen requires landscape before play; rotating upright also pauses the Godot scene tree and releases input. The home-screen manifest requests landscape. Full-screen mode requests an orientation lock where supported; the rotate screen provides the fallback when a browser cannot lock orientation.

Solo progress is stored in IndexedDB on the current browser origin. The existing temporary-file and backup-save behavior is preserved. Packaged item discovery handles Godot's `.tres.remap` resources. Browser QA confirmed gathered wood and starter inventory reached IndexedDB. Device-to-device sync and online accounts are not included.

The current multiplayer transport is ENet/UDP; the browser version needs a browser-compatible transport/service before Friends can support online sessions. The Friends interface explains this limitation in web builds. Sites identity and exact published artifacts are retained separately in the `sites/wildbound-play` checkout.
