# Playtest Results (Runs A through J)

- **Run A**: Verified basic encounter trigger. Passed.
- **Run B**: Ratelit Defiance trigger tested. +25% Power applied correctly at <30% HP. Passed.
- **Run C**: Pangolet Armor trigger tested. +35% Guard applied correctly at <40% HP. Passed.
- **Run D**: Meerkit Sentry trigger tested. Priority bonus worked, but caused a minor UI glitch. Fixed. Passed.
- **Run E**: Turn order & agility check. Passed.
- **Run F**: Wildbond probability calculation. Captured Ratelit at 15% HP. Passed.
- **Run G**: PartyManager limit tested. Trying to capture with full party sends creature to PC (mocked). Passed.
- **Run H**: Save/Load serialization roundtrip. Passed.
- **Run I**: EncounterTable distribution. 100 encounters generated expected ratios. Passed.
- **Run J**: Full end-to-end combat sequence without captures. Passed.
