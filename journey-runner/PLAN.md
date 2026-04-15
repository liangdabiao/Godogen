# Game Plan: 西游记跑酷 (Journey Runner)

## Game Description

跑酷游戏，以西游记为背景。玩家扮演孙悟空，在云端、山峦、河流等场景中奔跑跳跃，躲避障碍物，收集蟠桃和金丹，使用筋斗云和七十二变等能力。

## Risk Tasks

### 1. Procedural Level Generation [DONE]
- **Why isolated:** Endless runner needs platforms spawned at reachable distances with fair difficulty curve.
- **Verify:** Player can always reach the next platform; gap widths and heights stay within jump range; difficulty scales gradually over distance; no dead-end layouts; 60-second playthrough without unfair deaths.
- **Result:** Implemented with lazy-loaded scene references, difficulty scaling, and jump-reachable gaps.

## Main Build [DONE]

- **Assets:**
  - `bg_sky`, `bg_mountains`, `bg_clouds`, `bg_foreground` — parallax backgrounds (assets/img/)
  - `player` — Sun Wukong sprite (assets/img/player.png)
  - `platform` — golden cloud platform (assets/img/platform.png)
  - `collectibles_kit_nobg` — peach, pill, cloud items with transparency (assets/img/collectibles_kit_nobg.png)
  - `obstacles_kit` — stone pillar, rock (assets/img/obstacles_kit.png)
  - `enemy` — flying demon (assets/img/enemy.png)

- **Implemented systems:**
  - Player auto-run with jump, double-jump, slide
  - Procedural platform generation with difficulty scaling
  - Collectible pickup via distance detection
  - Parallax scrolling backgrounds (4 layers)
  - HUD with score, distance, lives, peach count
  - Game over screen with restart
  - Invincibility frames after damage
  - Start screen with instructions

- **Verify:**
  - [x] Player auto-runs, input response feels snappy
  - [x] Jump height and double-jump feel natural
  - [x] Platform collision is solid
  - [x] Collectibles picked up on contact (score increases)
  - [x] Score increments on collectible pickup and distance
  - [x] UI readable — score, distance, lives all update correctly
  - [x] Parallax backgrounds scroll at correct relative speeds
  - [x] Game over screen with score summary and restart
  - [x] reference.png consistency: color palette, camera angle
  - [x] **Presentation video:** ~30s cinematic MP4 (screenshots/presentation/gameplay.mp4)
