# Acu-Master · 神针手

A Roblox memory and precision party game for 2–12 players. Study the meridian mannequin, match the patient's clue to a body region, then rotate into view and place a needle on the virtual point. The clinic uses procedural geometry and a local 3D patient view. It needs no uploaded meshes, animations, or sound assets.

## Play in Roblox Studio

1. Open **Acu-Master.rbxl** in Roblox Studio and choose **Play**.
2. Complete or skip the opening walkthrough, then select **Solo practice** for four untimed lessons covering front, back, sole, and crown placements.
3. For a multiplayer check, select **Server & Clients** in Studio’s **Test** tab, set the client count to two, then start the test. Complete or skip the walkthrough in both clients to enter the match queue.

For a published experience, set the Roblox place’s maximum player count to 12 in Creator Dashboard. The in-game queue caps each match at 12 and lets additional players watch.

## Controls

| Input | Aim and confirm | Rotate | Back |
| --- | --- | --- | --- |
| Mouse | Move and click on the patient, or press Space | Q / E or view buttons | Backspace or Back |
| Touch | Drag on the patient. Release to select a region. Tap **Place needle** to confirm the point. The reticle sits above your finger. | View buttons or drag during study | Back |
| Gamepad | Left stick to aim, A to confirm | LB / RB | B |

The **Motion** setting reduces camera motion, dynamic sway, warning flashes, and the countdown sound. In study and recap, selecting an acupoint card turns the mannequin to its view. The study screen defaults to a detailed human figure. Use **Show blocks** or gamepad **Y** to switch models. The choice applies to solo lesson prep and multiplayer study. The placement stage uses the block patient.

## Match rules

- The match opens with three randomly selected points marked in red. Players can study as long as they need before tapping **Ready**. When at least half of the active players are ready, a 10-second study countdown starts. This ready check repeats whenever the game introduces new points.
- The first action round lasts 10 seconds. Later rounds last 12 seconds, and each of the first three rounds requires one placement.
- Round 3 adds three points. Rounds 4 onward require two ordered placements. Round 6 adds sway and brief guards. Later study breaks introduce more points until the pool reaches 20.
- The fastest valid finish gains 2 Qi. Other finishers gain 1 Qi, except the last finisher, who gains 0. A lone finisher gains 2. A wrong placement or timeout costs 1 Qi. A wrong region or a guard temporarily locks input.
- Players start with 3 Qi. At zero, they switch to spectator mode and can cheer active practitioners. The last surviving player wins. A simultaneous elimination triggers five-second sudden-death rounds until someone lands a valid hit.
- The clues use fictionalized scenarios inspired by traditional acupoint lore. The positions are represented on a stylized game mannequin.

## Edit the source

Install Rojo 7.x and open the extracted project folder. Run `rojo build -o Acu-Master.rbxl` to create a fresh place, or run `rojo serve` and connect the Rojo Studio plugin to edit the same project live.

```text
src/shared/   Acupoints, rig geometry, hit rules, and network types
src/server/   Authoritative match loop and Qi scoring
src/client/   Interface, camera, projected input, and procedural patient
```

The server owns timing, ranking, stage progression, eligibility, and scoring. The client submits a round ID, step, timestamp, and position in canonical rig space. The server checks the current phase, region, input window, visible surface, and point tolerance.

## Verification

Rojo 7.7.1 built the place. The Luau compiler and Roblox-aware strict type analysis passed. A deterministic Luau simulation exercised the match phase transitions, stale inputs, ranked scoring, study readiness and countdowns, late joins, cheering, combos, elimination, and sudden death. A geometry check traced all 20 points at three viewport sizes and confirmed that interior placements were rejected. Roblox Studio play-testing and device emulation require Studio.
