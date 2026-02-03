GOMA

GOMA – Guardian of Masked Artifacts is a 2D adventure about Goma, a soft little hero chosen to protect powerful, enchanted masks. Each mask Goma finds holds a unique ability, letting you jump higher, glide, or slip past new kinds of obstacles. By traveling through different worlds and collecting these masked artifacts, you’ll combine abilities, solve light puzzles, and overcome tougher challenges in every new level.

How to Play:
Move: A = left, D = right, W = up, S = down
Jump: Space bar
Switch masks: 1, 2, 3, 4 to select different mask abilities

Made by JD & AL

Game Engine: Godot v4
Assets: https://kenney.nl/
Music: opengameart.org
Source: https://github.com/uging/ggj2026


Proposed Folder Structure
res://
├── assets/                  <-- All raw visual/audio data
│   ├── env/                 <-- (Old /resources files: tilesets, clouds)
│   ├── audio/               <-- (Old /resources/sounds)
│   ├── fonts/               <-- (Old /resources/fonts)
│   └── items/               <-- (Pickups like heart.png)
├── common/                  <-- Global systems (The "Engine" of your game)
│   ├── autoloads/           <-- (Global.gd, scene_manager.gd)
│   ├── doors/               <-- (Exit nodes, game over triggers)
│   └── save_system/         <-- (save_manager.gd)
├── entities/                <-- Everything that "lives" in the world
│   ├── player/              <-- (All Goma-related scenes/scripts/assets)
│   ├── enemies/             <-- (Lava snake, Snail, Traps)
│   └── interactables/       <-- (Move /entities/player/interactables here)
├── levels/                  <-- Your actual playable stages
│   ├── basic_level/
│   ├── pyramid_level/
│   └── tower_level/
├── ui/                      <-- All screens and overlays
│   ├── hud/                 <-- (hud.tscn, hud.gd)
│   ├── main_menu/           <-- (title.tscn, start_button.gd)
│   └── game_over/           <-- (game_over_layer.tscn)
└── project.godot
