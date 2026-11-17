# Worker walk animation artwork

The built-in image generation tool extended the supplied FedUp Delivery Worker Sprite Sheet. The finished assets contain 12 separately drawn poses per direction (48 total), stored as transparent atlases. These are AI-assisted extensions of the user's supplied character artwork.

Assets: `assets/art/presentation/worker-walk-front.png`, `worker-walk-back.png`, `worker-walk-left.png`, `worker-walk-right.png`.

Playback uses `data/worker_walk.json` to register each drawing's head center and common floor line, with fixed scale per direction. `tools/register_worker_walk.py` inspects alpha only and never edits image pixels. Body bob, tilt and mirrored side lettering have been removed from normal walking. One 2.8-meter gait cycle gives 18 pose changes/sec at 4.2 m/sec and about 28 when sprinting. The same animation code and atlases run in native and browser exports.

Final built-in tool prompts (each used its matching generated character atlas as the edit target; the supplied user sheet defined character identity):

## front

```text
Correct this character animation atlas into ONE physically coherent 12-frame walking cycle. Preserve the exact supplied character design, crisp ink, original costume, logos, palette, body proportions and camera direction (FRONT) from this edit target. This is final in-game animation artwork. TRUE TRANSPARENT BACKGROUND: RGBA alpha ZERO everywhere outside the character, no colored gradients, no shadows, no checkerboard. Every cell empty except its single complete character.
IMPORTANT NEW LAYOUT: EXACTLY SIX COLUMNS and TWO ROWS. Twelve equally spaced full-body character drawings, chronological left to right across top row frames 1-6, then left to right across bottom row frames 7-12. Each cell a tall rectangle on a 1536x1024 canvas. Keep identical head center and ground baseline within all cells, character height about 420 pixels, leave 35px clear transparent margin top/bottom and 30px lateral. Do not clip any boots, hands, hat or outline.
The previous atlas has near-duplicate legs and repeats half-cycles. Replace that with the following actual progression of joint poses. The TOP ROW contains one half-stride. BOTTOM ROW contains the OTHER half-stride, with left/right arms and legs swapped. No third half-stride, no turnaround, no changes of viewing angle, no whole-character tilts or scaling tricks.
1 LEFT foot forward heel-contact, RIGHT foot behind on toe; RIGHT arm forward LEFT arm back.
2 LEFT foot plants and takes weight, left knee bends, RIGHT heel lifts, right knee starts to bend.
3 LEFT foot supports under hip, RIGHT knee bent and RIGHT boot passes beside the planted LEFT leg (BOTH BOOTS CLOSE TOGETHER at this passing pose); arms near middle of swing.
4 LEFT support foot moves behind hip, RIGHT knee travels forward and RIGHT boot lifts, LEFT arm now swinging forward.
5 RIGHT lower leg extends forward, RIGHT heel descends toward ground, LEFT heel peels up at rear, LEFT arm forward.
6 RIGHT heel nearly contacts in front, LEFT foot is now behind on toe, completing the first half stride.
7 RIGHT foot forward heel-contact, LEFT foot behind on toe; LEFT arm forward RIGHT arm back.
8 RIGHT foot plants and takes weight, right knee bends, LEFT heel lifts, left knee starts to bend.
9 RIGHT foot supports under hip, LEFT knee bent and LEFT boot passes beside the planted RIGHT leg (BOTH BOOTS CLOSE TOGETHER at this passing pose); arms near middle of swing.
10 RIGHT support foot moves behind hip, LEFT knee travels forward and LEFT boot lifts, RIGHT arm now swinging forward.
11 LEFT lower leg extends forward, LEFT heel descends toward ground, RIGHT heel peels up at rear, RIGHT arm forward.
12 LEFT heel almost contacts in front, RIGHT foot behind on toe, connects smoothly to frame 1. Do not duplicate the first frame.
Face always TOWARD viewer, both eyes and shirt front visible. Foreshorten advancing boots naturally, and include the essential neutral/passing leg poses, not twelve raised-knee poses.
All twelve are new distinct drawings with articulated knees, ankles, arms, boots. No text, frame labels, panel borders, background or motion marks.
```

## back

```text
Correct this character animation atlas into ONE physically coherent 12-frame walking cycle. Preserve the exact supplied character design, crisp ink, original costume, logos, palette, body proportions and camera direction (BACK) from this edit target. This is final in-game animation artwork. TRUE TRANSPARENT BACKGROUND: RGBA alpha ZERO everywhere outside the character, no colored gradients, no shadows, no checkerboard. Every cell empty except its single complete character.
IMPORTANT NEW LAYOUT: EXACTLY SIX COLUMNS and TWO ROWS. Twelve equally spaced full-body character drawings, chronological left to right across top row frames 1-6, then left to right across bottom row frames 7-12. Each cell a tall rectangle on a 1536x1024 canvas. Keep identical head center and ground baseline within all cells, character height about 420 pixels, leave 35px clear transparent margin top/bottom and 30px lateral. Do not clip any boots, hands, hat or outline.
The previous atlas has near-duplicate legs and repeats half-cycles. Replace that with the following actual progression of joint poses. The TOP ROW contains one half-stride. BOTTOM ROW contains the OTHER half-stride, with left/right arms and legs swapped. No third half-stride, no turnaround, no changes of viewing angle, no whole-character tilts or scaling tricks.
1 LEFT foot forward heel-contact, RIGHT foot behind on toe; RIGHT arm forward LEFT arm back.
2 LEFT foot plants and takes weight, left knee bends, RIGHT heel lifts, right knee starts to bend.
3 LEFT foot supports under hip, RIGHT knee bent and RIGHT boot passes beside the planted LEFT leg (BOTH BOOTS CLOSE TOGETHER at this passing pose); arms near middle of swing.
4 LEFT support foot moves behind hip, RIGHT knee travels forward and RIGHT boot lifts, LEFT arm now swinging forward.
5 RIGHT lower leg extends forward, RIGHT heel descends toward ground, LEFT heel peels up at rear, LEFT arm forward.
6 RIGHT heel nearly contacts in front, LEFT foot is now behind on toe, completing the first half stride.
7 RIGHT foot forward heel-contact, LEFT foot behind on toe; LEFT arm forward RIGHT arm back.
8 RIGHT foot plants and takes weight, right knee bends, LEFT heel lifts, left knee starts to bend.
9 RIGHT foot supports under hip, LEFT knee bent and LEFT boot passes beside the planted RIGHT leg (BOTH BOOTS CLOSE TOGETHER at this passing pose); arms near middle of swing.
10 RIGHT support foot moves behind hip, LEFT knee travels forward and LEFT boot lifts, RIGHT arm now swinging forward.
11 LEFT lower leg extends forward, LEFT heel descends toward ground, RIGHT heel peels up at rear, RIGHT arm forward.
12 LEFT heel almost contacts in front, RIGHT foot behind on toe, connects smoothly to frame 1. Do not duplicate the first frame.
Face always AWAY from viewer, cap back/strap/hair and back-shirt FedUp logo visible. Lifted boot soles only during toe-off and swing, include the essential feet-together passing poses. No faces.
All twelve are new distinct drawings with articulated knees, ankles, arms, boots. No text, frame labels, panel borders, background or motion marks.
```

## left

```text
Correct this character animation atlas into ONE physically coherent 12-frame walking cycle. Preserve the exact supplied character design, crisp ink, original costume, logos, palette, body proportions and camera direction (LEFT) from this edit target. This is final in-game animation artwork. TRUE TRANSPARENT BACKGROUND: RGBA alpha ZERO everywhere outside the character, no colored gradients, no shadows, no checkerboard. Every cell empty except its single complete character.
IMPORTANT NEW LAYOUT: EXACTLY SIX COLUMNS and TWO ROWS. Twelve equally spaced full-body character drawings, chronological left to right across top row frames 1-6, then left to right across bottom row frames 7-12. Each cell a tall rectangle on a 1536x1024 canvas. Keep identical head center and ground baseline within all cells, character height about 420 pixels, leave 35px clear transparent margin top/bottom and 30px lateral. Do not clip any boots, hands, hat or outline.
The previous atlas has near-duplicate legs and repeats half-cycles. Replace that with the following actual progression of joint poses. The TOP ROW contains one half-stride. BOTTOM ROW contains the OTHER half-stride, with left/right arms and legs swapped. No third half-stride, no turnaround, no changes of viewing angle, no whole-character tilts or scaling tricks.
1 LEFT foot forward heel-contact, RIGHT foot behind on toe; RIGHT arm forward LEFT arm back.
2 LEFT foot plants and takes weight, left knee bends, RIGHT heel lifts, right knee starts to bend.
3 LEFT foot supports under hip, RIGHT knee bent and RIGHT boot passes beside the planted LEFT leg (BOTH BOOTS CLOSE TOGETHER at this passing pose); arms near middle of swing.
4 LEFT support foot moves behind hip, RIGHT knee travels forward and RIGHT boot lifts, LEFT arm now swinging forward.
5 RIGHT lower leg extends forward, RIGHT heel descends toward ground, LEFT heel peels up at rear, LEFT arm forward.
6 RIGHT heel nearly contacts in front, LEFT foot is now behind on toe, completing the first half stride.
7 RIGHT foot forward heel-contact, LEFT foot behind on toe; LEFT arm forward RIGHT arm back.
8 RIGHT foot plants and takes weight, right knee bends, LEFT heel lifts, left knee starts to bend.
9 RIGHT foot supports under hip, LEFT knee bent and LEFT boot passes beside the planted RIGHT leg (BOTH BOOTS CLOSE TOGETHER at this passing pose); arms near middle of swing.
10 RIGHT support foot moves behind hip, LEFT knee travels forward and LEFT boot lifts, RIGHT arm now swinging forward.
11 LEFT lower leg extends forward, LEFT heel descends toward ground, RIGHT heel peels up at rear, RIGHT arm forward.
12 LEFT heel almost contacts in front, RIGHT foot behind on toe, connects smoothly to frame 1. Do not duplicate the first frame.
Always face LEFT in side profile. Contact poses have split legs, passing poses have close legs, swing poses have visibly bent knees. Near and far limbs must trade support across the two rows; do not just move the same leg forward again. All visible lettering readable and never mirrored.
All twelve are new distinct drawings with articulated knees, ankles, arms, boots. No text, frame labels, panel borders, background or motion marks.
```

## right

```text
Correct this character animation atlas into ONE physically coherent 12-frame walking cycle. Preserve the exact supplied character design, crisp ink, original costume, logos, palette, body proportions and camera direction (RIGHT) from this edit target. This is final in-game animation artwork. TRUE TRANSPARENT BACKGROUND: RGBA alpha ZERO everywhere outside the character, no colored gradients, no shadows, no checkerboard. Every cell empty except its single complete character.
IMPORTANT NEW LAYOUT: EXACTLY SIX COLUMNS and TWO ROWS. Twelve equally spaced full-body character drawings, chronological left to right across top row frames 1-6, then left to right across bottom row frames 7-12. Each cell a tall rectangle on a 1536x1024 canvas. Keep identical head center and ground baseline within all cells, character height about 420 pixels, leave 35px clear transparent margin top/bottom and 30px lateral. Do not clip any boots, hands, hat or outline.
The previous atlas has near-duplicate legs and repeats half-cycles. Replace that with the following actual progression of joint poses. The TOP ROW contains one half-stride. BOTTOM ROW contains the OTHER half-stride, with left/right arms and legs swapped. No third half-stride, no turnaround, no changes of viewing angle, no whole-character tilts or scaling tricks.
1 LEFT foot forward heel-contact, RIGHT foot behind on toe; RIGHT arm forward LEFT arm back.
2 LEFT foot plants and takes weight, left knee bends, RIGHT heel lifts, right knee starts to bend.
3 LEFT foot supports under hip, RIGHT knee bent and RIGHT boot passes beside the planted LEFT leg (BOTH BOOTS CLOSE TOGETHER at this passing pose); arms near middle of swing.
4 LEFT support foot moves behind hip, RIGHT knee travels forward and RIGHT boot lifts, LEFT arm now swinging forward.
5 RIGHT lower leg extends forward, RIGHT heel descends toward ground, LEFT heel peels up at rear, LEFT arm forward.
6 RIGHT heel nearly contacts in front, LEFT foot is now behind on toe, completing the first half stride.
7 RIGHT foot forward heel-contact, LEFT foot behind on toe; LEFT arm forward RIGHT arm back.
8 RIGHT foot plants and takes weight, right knee bends, LEFT heel lifts, left knee starts to bend.
9 RIGHT foot supports under hip, LEFT knee bent and LEFT boot passes beside the planted RIGHT leg (BOTH BOOTS CLOSE TOGETHER at this passing pose); arms near middle of swing.
10 RIGHT support foot moves behind hip, LEFT knee travels forward and LEFT boot lifts, RIGHT arm now swinging forward.
11 LEFT lower leg extends forward, LEFT heel descends toward ground, RIGHT heel peels up at rear, RIGHT arm forward.
12 LEFT heel almost contacts in front, RIGHT foot behind on toe, connects smoothly to frame 1. Do not duplicate the first frame.
Always face RIGHT in side profile. Contact poses have split legs, passing poses have close legs, swing poses have visibly bent knees. Near and far limbs must trade support across the two rows; do not just move the same leg forward again. All visible lettering readable and never mirrored.
All twelve are new distinct drawings with articulated knees, ankles, arms, boots. No text, frame labels, panel borders, background or motion marks.
```

