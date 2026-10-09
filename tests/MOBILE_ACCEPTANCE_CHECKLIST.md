# Android RC1 acceptance checklist

**Real-device acceptance pending.** See [the implementation report](../docs/MOBILE_IMPLEMENTATION_REPORT.md) for completed engine/rendered tests. APK compilation and Windows touch simulation do not certify Android playability.

## Device record

- Tester/date:
- Phone model / Android version:
- Screen size, cutout and navigation mode:
- APK SHA-256 from `builds/RC1_BUILD_INFO.json`:
- Quality preset:
- Session length, start/end battery percentage:
- Average FPS, worst frame spikes, memory:
- Heating, crashes, audio or control issues:

Record actual phone measurements, not desktop estimates.

## Install and 30-minute touch-only session

- [ ] Install the APK and launch without crashing. Confirm landscape.
- [ ] Rotate upright and back: gameplay cannot continue in portrait, and input recovers sideways.
- [ ] Check cutouts, gesture areas and text/control overlap; repeat on another landscape aspect ratio when available.
- [ ] Move slowly/diagonally/full speed, release reliably, move while tapping Jump/Interact.
- [ ] Adjust deadzone and reopen Settings to check persistence.
- [ ] Gather, talk and deliberately search grass; menu touches do not move/interact with the world.
- [ ] Trigger a wild encounter and use Strike, Skills, Guard, Items, Wildbond, Creatures and Flee.
- [ ] Test failed/successful Wildbond using normal rules; bonded creature survives restart.
- [ ] Exercise faint replacement, defeat and victory; no keyboard is required to continue.
- [ ] Check separate HP/XP, visible Instinct/status effects and no duplicate turns on rapid taps.
- [ ] Open six-member party/details, set lead/favorite and finger-scroll long lists.
- [ ] Transfer/swap a favorite at Acacia Outpost; restart and compare identities/counts.
- [ ] Reject transfers elsewhere and removal of the last conscious companion.
- [ ] With saddle and companion, mount/ride/jump/dismount; controls/camera recover.
- [ ] With Vulturon/harness, Rise/steer/Descend/Land; check altitude, ring and unsafe landing.
- [ ] Fly over water, structures and boundaries without clipping or a stuck descent.
- [ ] Gather, select a structure, move its cursor while keeper stays still, rotate and cancel.
- [ ] Place on valid ground; reject water/edge/occupied/insufficient-material attempts without charge.
- [ ] Rapid placement taps charge once; immediate Undo refunds once. Re-place and check after restart.
- [ ] Save, fully close and reopen; compare region/location, party, Reserve, gear, supplies and buildings.
- [ ] Complete 30 minutes using only touch; record every blocked or uncomfortable interaction.

## Interruptions

- [ ] Android Back closes submenu/detail/menu/dialogue/construction, then opens Settings from exploration without quitting.
- [ ] Home/app switching/locking during movement releases the stick; return without unintended movement.
- [ ] Repeat during resolving battle, faint selection, dialogue, menus and building.
- [ ] Battle pauses in background and resumes once; no skipped turns or duplicate rewards.
- [ ] Audio recovers after lock and another app using audio.
- [ ] Terminate in background and reopen: restore the checkpoint; mid-battle recovery uses the last completed checkpoint.
- [ ] A safely reproduced save failure does not say Saved or destroy the prior valid checkpoint.

## Performance — 20 continuous minutes

- [ ] Medium preset: measure FPS/frame spikes, memory, heat and battery.
- [ ] Include dense grass, creatures, battle, flight and constructed buildings.
- [ ] Target sustained 30 FPS; record stalls/thermal slowdown, not only an initial average.
- [ ] Compare Low if necessary; visual reductions must not alter mechanics.
- [ ] High/60 FPS is optional. Record crashes, OS termination and resume issues.

## Friends — optional separate experiment

- [ ] Solo works after opening/closing Friends.
- [ ] Two native devices, reachable LAN host address and matching port; loopback is not another device.
- [ ] Check consent, battle, trade, disconnect and unchanged solo saves.
- [ ] Do not expose private ENet ports publicly; browser online play requires a compatible transport/service.
- [ ] Keep multiplayer marked unverified until tested between separate devices.

Decision: PASS / FAIL / BLOCKED, with device evidence and specific remaining issues.
