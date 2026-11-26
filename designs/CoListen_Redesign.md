# CoListen — Redesign Spec

**Direction:** "Midnight Studio" — calm, dark, album-art-first. Fewer boxes, more breathing room, one hero action per screen. The purple→cyan gradient is reserved for primary actions and the sync state.

## Logo
Two overlapping rings (two listeners) with three equalizer bars where they meet (sync). Gradient `#7C4DFF → #00E5FF` on `#0D0D12`. App icon: rounded square (22% radius). Wordmark "CoListen" in Sora 700.

## Tokens
| Token | Value | Use |
|---|---|---|
| bg | #0D0D12 | canvas |
| surface | #161622 | cards |
| surface-hi | #1E1E2E | inputs, chips |
| primary | #7C4DFF | main CTA |
| accent | #00E5FF | sync, highlights |
| success / warning / error | #00E676 / #FFD600 / #FF1744 | status |
| text / text-2 / muted | #FFFFFF / #A0A0B8 / #62627A | type |
| border | rgba(255,255,255,.08) | glass strokes |

Type: Sora (headings 700), Inter (body). Scale 28/20/16/14/12. Radius 20 cards, 999 pills. 4-pt spacing grid. Motion 200ms ease-out; emoji bursts 1.2s; EQ bars 600ms loop.

## 1. Login
- Centered logo (96px) with soft purple glow, EQ bars animating beneath.
- Headline "Listen together. In sync." plus one line of subtext.
- Bottom stack: **Continue with Google** (white pill), **Continue as Guest** (glass outline).
- Guest sheet: handle, "Choose your DJ handle", input, gradient "Enter as Guest".

## 2. Home
- Top bar: logo mark + avatar with presence ring. Menu: name, Sign out (red).
- Invite banner when present: glass card, "Mia invited you to Late Night Lo-Fi", Decline / Join.
- Two big side-by-side actions: **Create Room** (gradient), **Enter Code** (outline).
- "Recent rooms": art tile, title, #CODE chip, "Host • 3 listening", live dot or "Ended". Tap = one-tap re-entry; swipe left to remove.
- Empty state: illustration plus short helper text.

## 3. Create Room (sheet)
Name field with dice button, two switches (members add songs, vote-to-skip), full-width gradient button with loading state.

## 4. Join Code (sheet)
Six individual character boxes, Paste chip, inline error text, **Join Room** button.

## 5. Room
- Top: back, code pill (tap to copy), member count, share.
- Segmented control (App Player | YouTube Hub) above a large 16:9 stage with purple glow.
- Title, artist, small chips (YouTube, Ad blocker active).
- Waveform scrubber (locked for listeners, small lock icon).
- Controls: prev, big gradient play/pause, next; "Vote skip 1/2" chip.
- "● In sync" badge. Bottom dock: Queue (primary), Members, emoji launcher that expands into the reaction bar. Reactions float over the stage.
- PiP: video only, edge to edge.

## 6. Queue (sheet)
"Up next · 4" + **Add song**. Now-playing card with EQ bars. Reorderable rows: grip, thumbnail, title/channel, duration, added-by, vote chip, delete (permission-based).

## 7. Add Song (sheet)
Search field with Paste. Empty state shows "Curated picks" with + buttons. Results: thumbnail with duration badge, title, channel, + button.

## 8. Members (sheet)
Rows with avatar + presence ring, name, role badge (Host gold, DJ cyan, Listener grey). Host sees a DJ Control switch and a remove-member action.

## 9. Android Media Notification
Title, artist, scrubber, prev/play/next, small CoListen mark. Swiping away stops local audio only.
