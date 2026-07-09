extends RefCounted
class_name StageContentDatabase

const PATTERN_ALIASES := {
	"s1_lantern_nonspell": "moonlight",
	"s1_star_procession": "starfall",
	"s1_fox_butterfly": "butterfly",
	"s1_boundary_finale": "divine",
	"s2_market_nonspell": "ripple",
	"s2_coin_bubble": "bubble",
	"s2_object_mist": "mist",
	"s2_abacus_mirror": "mirror",
	"s3_mist_nonspell": "scarlet",
	"s3_bamboo_blade": "midnight",
	"s3_memory_vortex": "vortex",
	"s3_dark_path": "darkness",
	"s4_wind_nonspell": "wind_aimed",
	"s4_newspaper_lattice": "wind_lattice",
	"s4_tengu_gale": "midnight",
	"s4_sky_report": "wind_lattice",
	"s5_rhythm_nonspell": "rhythm_drum",
	"s5_oni_fire": "scarlet",
	"s5_large_orb_spell": "large_orb_gate",
	"s5_drum_vortex": "vortex",
	"s5_banquet_darkness": "darkness",
	"s6_faith_nonspell": "final_lantern",
	"s6_lantern_rain": "apocalypse",
	"s6_final_lantern_spell": "final_lantern",
	"s6_hyakki_gate": "large_orb_gate",
	"s6_festival_darkness": "darkness",
}

const STAGES := [
	{
		"index": 1,
		"stage_id": "shrine_approach",
		"display_name": "\u795e\u793e\u53c2\u9053",
		"theme": "bright_festival_opening",
		"curve_tag": "basic_collection",
		"boss_time": 4500,
		"waves": [
			{"time": 0, "x": 100, "y": -20, "hp": 4, "pattern": "downward", "move": "straight", "vx": 0.0, "vy": 1.5, "repeat": 3, "spacing_x": 140.0, "spacing_y": -10.0},
			{"time": 120, "x": 240, "y": -20, "hp": 5, "pattern": "spread", "move": "enter_and_stop", "vx": 0.0, "vy": 2.5, "move_data": {"move_time": 55}},
			{"time": 300, "x": 95, "y": -20, "hp": 3, "pattern": "aimed", "move": "sine", "vx": 0.0, "vy": 1.5, "repeat": 4, "spacing_x": 90.0, "spacing_y": -12.0, "move_data": {"amplitude": 22}},
			{"time": 540, "x": 240, "y": 30, "hp": 12, "pattern": "ring", "move": "sine", "vx": 0.8, "vy": 0.5, "move_data": {"amplitude": 50}},
			{"time": 780, "x": 80, "y": -20, "hp": 6, "pattern": "spread", "move": "enter_and_stop", "vx": 0.0, "vy": 2.0, "repeat": 2, "spacing_x": 320.0, "move_data": {"move_time": 60}},
			{"time": 1080, "x": 70, "y": -20, "hp": 3, "pattern": "aimed", "move": "sine", "vx": 0.0, "vy": 1.6, "repeat": 5, "spacing_x": 85.0, "spacing_y": -15.0, "move_data": {"amplitude": 25}},
			{"time": 1380, "x": 140, "y": 30, "hp": 14, "pattern": "ring", "move": "circle", "vx": 0.0, "vy": 0.0, "repeat": 2, "spacing_x": 200.0, "move_data": {"center_x": 160, "center_y": 100, "radius": 50}},
			{"time": 1740, "x": 80, "y": -30, "hp": 4, "pattern": "downward", "move": "enter_and_stop", "vx": 0.0, "vy": 1.4, "repeat": 4, "spacing_x": 100.0, "move_data": {"move_time": 70}},
			{"time": 2100, "x": -20, "y": 180, "hp": 5, "pattern": "aimed", "move": "straight", "vx": 2.0, "vy": 0.0, "repeat": 2, "spacing_x": 520.0, "spacing_y": 40.0, "variants": [{"vx": 2.0}, {"vx": -2.0}]},
			{"time": 2500, "x": 240, "y": 40, "hp": 20, "pattern": "double_spread", "move": "sine", "vx": 0.3, "vy": 0.7, "move_data": {"amplitude": 80}, "strong": true},
			{"time": 2900, "x": 120, "y": -25, "hp": 6, "pattern": "spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.6, "repeat": 3, "spacing_x": 120.0, "move_data": {"move_time": 70}},
			{"time": 3300, "x": 240, "y": 60, "hp": 22, "pattern": "ring", "move": "sine", "vx": 0.2, "vy": 0.5, "move_data": {"amplitude": 70}, "strong": true},
			{"time": 3700, "x": 70, "y": -20, "hp": 5, "pattern": "spread", "move": "straight", "vx": 1.2, "vy": 1.3, "repeat": 2, "spacing_x": 340.0, "variants": [{"vx": 1.2}, {"vx": -1.2}]},
			{"time": 4000, "x": 240, "y": -20, "hp": 35, "pattern": "double_spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.8, "move_data": {"move_time": 80}, "strong": true},
			{"time": 4200, "x": 90, "y": -15, "hp": 4, "pattern": "spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.8, "repeat": 4, "spacing_x": 95.0, "spacing_y": -8.0, "move_data": {"move_time": 65}},
		],
		"midboss": {
			"id": "lantern_tsukumogami",
			"display_name": "\u63d0\u706f\u4ed8\u4e27\u795e",
			"cards": [
				{"name": "\u591c\u706f\u300c\u53c2\u9053\u63d0\u706f\u5217\u300d", "hp": 320, "time": 16, "pattern": "s1_lantern_nonspell", "kind": "nonspell"},
				{"name": "\u706f\u7b26\u300c\u5c0f\u3055\u306a\u796d\u308a\u706b\u300d", "hp": 420, "time": 18, "pattern": "s1_star_procession", "kind": "spell"},
			],
		},
		"boss": {
			"id": "festival_guide_fox",
			"display_name": "\u796d\u5178\u5f15\u8def\u72d0",
			"cards": [
				{"name": "\u5c0e\u706b\u300c\u72d0\u306e\u53c2\u9053\u6848\u5185\u300d", "hp": 600, "time": 28, "pattern": "s1_lantern_nonspell", "kind": "nonspell"},
				{"name": "\u661f\u7b26\u300c\u795e\u793e\u661f\u96e8\u300d", "hp": 900, "time": 32, "pattern": "s1_star_procession", "kind": "spell"},
				{"name": "\u8776\u7b26\u300c\u591c\u796d\u306e\u7d19\u8776\u300d", "hp": 1300, "time": 30, "pattern": "s1_fox_butterfly", "kind": "spell"},
				{"name": "\u7d50\u754c\u300c\u521d\u591c\u306e\u795e\u7f70\u300d", "hp": 1600, "time": 25, "pattern": "s1_boundary_finale", "kind": "spell"},
			],
		},
	},
	{
		"index": 2,
		"stage_id": "yokai_market",
		"display_name": "\u5996\u602a\u5e02\u96c6",
		"theme": "tools_and_trade",
		"curve_tag": "horizontal_objects",
		"boss_time": 4800,
		"waves": [
			{"time": 0, "x": 80, "y": -20, "hp": 5, "pattern": "spread", "move": "straight", "vx": 0.0, "vy": 1.5, "repeat": 3, "spacing_x": 160.0},
			{"time": 100, "x": 240, "y": -20, "hp": 8, "pattern": "double_spread", "move": "enter_and_stop", "vx": 0.0, "vy": 2.0, "move_data": {"move_time": 60}},
			{"time": 250, "x": 80, "y": -20, "hp": 3, "pattern": "aimed", "move": "sine", "vx": 0.0, "vy": 1.4, "repeat": 5, "spacing_x": 80.0, "spacing_y": -10.0, "move_data": {"amplitude": 28}},
			{"time": 480, "x": 240, "y": 30, "hp": 16, "pattern": "ring", "move": "sine", "vx": 0.6, "vy": 0.5, "move_data": {"amplitude": 60}, "strong": true},
			{"time": 720, "x": 70, "y": -20, "hp": 9, "pattern": "double_spread", "move": "enter_and_stop", "vx": 0.0, "vy": 2.0, "repeat": 2, "spacing_x": 340.0, "move_data": {"move_time": 65}},
			{"time": 1000, "x": 60, "y": -15, "hp": 5, "pattern": "aimed", "move": "sine", "vx": 0.0, "vy": 1.7, "repeat": 4, "spacing_x": 120.0, "move_data": {"amplitude": 30}},
			{"time": 1300, "x": 100, "y": 30, "hp": 20, "pattern": "ring", "move": "circle", "vx": 0.0, "vy": 0.0, "repeat": 2, "spacing_x": 280.0, "move_data": {"center_x": 120, "center_y": 90, "radius": 60}, "strong": true},
			{"time": 1600, "x": 60, "y": -25, "hp": 5, "pattern": "wave", "move": "enter_and_stop", "vx": 0.0, "vy": 1.6, "repeat": 5, "spacing_x": 90.0, "spacing_y": -8.0, "move_data": {"move_time": 65}},
			{"time": 1900, "x": -20, "y": 150, "hp": 7, "pattern": "aimed", "move": "straight", "vx": 2.5, "vy": 0.2, "repeat": 2, "spacing_x": 520.0, "spacing_y": 40.0, "variants": [{"vx": 2.5, "vy": 0.2}, {"vx": -2.5, "vy": -0.1}]},
			{"time": 2250, "x": 240, "y": 40, "hp": 25, "pattern": "double_spread", "move": "sine", "vx": 0.4, "vy": 0.4, "move_data": {"amplitude": 70}, "strong": true},
			{"time": 2600, "x": 80, "y": -30, "hp": 8, "pattern": "spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.8, "repeat": 4, "spacing_x": 105.0, "move_data": {"move_time": 75}},
			{"time": 2950, "x": 240, "y": 50, "hp": 30, "pattern": "ring", "move": "sine", "vx": 0.3, "vy": 0.4, "move_data": {"amplitude": 90}, "strong": true},
			{"time": 3300, "x": 70, "y": -20, "hp": 10, "pattern": "double_spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.5, "repeat": 3, "spacing_x": 170.0, "move_data": {"move_time": 70}},
			{"time": 3950, "x": 240, "y": -20, "hp": 40, "pattern": "double_spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.6, "move_data": {"move_time": 85}, "strong": true},
			{"time": 4500, "x": 80, "y": -20, "hp": 4, "pattern": "downward", "move": "straight", "vx": 0.0, "vy": 1.5, "repeat": 9, "spacing_x": 40.0, "spacing_y": -4.0},
		],
		"midboss": {
			"id": "abacus_tsukumogami",
			"display_name": "\u7b97\u76e4\u4ed8\u4e27\u795e",
			"cards": [
				{"name": "\u7b97\u7b26\u300c\u5e02\u96c6\u306e\u6a2a\u5217\u300d", "hp": 420, "time": 17, "pattern": "s2_market_nonspell", "kind": "nonspell"},
				{"name": "\u73e0\u7b26\u300c\u8df3\u306d\u308b\u305d\u308d\u3070\u3093\u7389\u300d", "hp": 520, "time": 19, "pattern": "s2_coin_bubble", "kind": "spell"},
			],
		},
		"boss": {
			"id": "oni_market_leader",
			"display_name": "\u5e02\u96c6\u306e\u9b3c\u982d",
			"cards": [
				{"name": "\u5e02\u7b26\u300c\u5996\u5e02\u306e\u5024\u5207\u308a\u300d", "hp": 900, "time": 28, "pattern": "s2_market_nonspell", "kind": "nonspell"},
				{"name": "\u6ce1\u7b26\u300c\u9285\u8ca8\u306e\u6ce1\u6d8c\u304d\u300d", "hp": 1300, "time": 32, "pattern": "s2_coin_bubble", "kind": "spell"},
				{"name": "\u9053\u5177\u300c\u8ff7\u5b50\u306e\u9053\u5177\u5c4b\u300d", "hp": 1800, "time": 30, "pattern": "s2_object_mist", "kind": "spell"},
				{"name": "\u93e1\u7b26\u300c\u8a08\u308a\u76f4\u3057\u306e\u6c34\u93e1\u300d", "hp": 2400, "time": 25, "pattern": "s2_abacus_mirror", "kind": "spell"},
			],
		},
	},
	{
		"index": 3,
		"stage_id": "mist_bamboo_grove",
		"display_name": "\u8ff7\u9727\u7af9\u6797",
		"theme": "fog_and_wrong_paths",
		"curve_tag": "mist_memory",
		"boss_time": 5400,
		"waves": [
			{"time": 0, "x": 60, "y": -20, "hp": 7, "pattern": "spread", "move": "straight", "vx": 0.0, "vy": 1.5, "repeat": 4, "spacing_x": 120.0},
			{"time": 80, "x": 240, "y": -20, "hp": 10, "pattern": "spiral", "move": "enter_and_stop", "vx": 0.0, "vy": 2.2, "move_data": {"move_time": 55}},
			{"time": 200, "x": 70, "y": -20, "hp": 5, "pattern": "mist_delay", "move": "sine", "vx": 0.0, "vy": 1.5, "repeat": 4, "spacing_x": 100.0, "move_data": {"amplitude": 25}},
			{"time": 400, "x": 240, "y": 30, "hp": 22, "pattern": "ring", "move": "sine", "vx": 0.8, "vy": 0.4, "move_data": {"amplitude": 65}, "strong": true},
			{"time": 600, "x": 60, "y": -15, "hp": 7, "pattern": "aimed", "move": "sine", "vx": 0.0, "vy": 1.8, "repeat": 4, "spacing_x": 120.0, "move_data": {"amplitude": 35}},
			{"time": 850, "x": -20, "y": 140, "hp": 8, "pattern": "double_spread", "move": "straight", "vx": 2.8, "vy": 0.1, "repeat": 2, "spacing_x": 520.0, "spacing_y": 30.0, "variants": [{"vx": 2.8}, {"vx": -2.8, "vy": -0.1}]},
			{"time": 1100, "x": 120, "y": 30, "hp": 25, "pattern": "ring", "move": "circle", "vx": 0.0, "vy": 0.0, "repeat": 2, "spacing_x": 240.0, "move_data": {"center_x": 120, "center_y": 80, "radius": 55}, "strong": true},
			{"time": 1350, "x": 60, "y": -20, "hp": 6, "pattern": "downward", "move": "enter_and_stop", "vx": 0.0, "vy": 1.5, "repeat": 4, "spacing_x": 100.0, "move_data": {"move_time": 65}},
			{"time": 1600, "x": 240, "y": 40, "hp": 35, "pattern": "double_spread", "move": "sine", "vx": 0.4, "vy": 0.5, "move_data": {"amplitude": 85}, "strong": true},
			{"time": 1900, "x": 70, "y": -25, "hp": 9, "pattern": "mist_delay", "move": "enter_and_stop", "vx": 0.0, "vy": 1.9, "repeat": 4, "spacing_x": 110.0, "move_data": {"move_time": 70}},
			{"time": 2200, "x": 100, "y": 30, "hp": 25, "pattern": "double_spread", "move": "sine", "vx": 0.5, "vy": 0.4, "move_data": {"amplitude": 60}, "strong": true},
			{"time": 2550, "x": 50, "y": -30, "hp": 7, "pattern": "spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.7, "repeat": 5, "spacing_x": 92.0, "spacing_y": -8.0, "move_data": {"move_time": 75}},
			{"time": 2900, "x": 240, "y": 50, "hp": 40, "pattern": "ring", "move": "sine", "vx": 0.2, "vy": 0.5, "move_data": {"amplitude": 95}, "strong": true},
			{"time": 3600, "x": 120, "y": -20, "hp": 25, "pattern": "double_spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.7, "repeat": 2, "spacing_x": 240.0, "move_data": {"move_time": 80}, "strong": true},
			{"time": 5050, "x": 80, "y": -20, "hp": 5, "pattern": "downward", "move": "straight", "vx": 0.0, "vy": 1.6, "repeat": 12, "spacing_x": 30.0, "spacing_y": -4.0},
		],
		"midboss": {
			"id": "lost_rabbit_yokai",
			"display_name": "\u8ff7\u3044\u514e\u5996\u602a",
			"cards": [
				{"name": "\u8ff7\u7b26\u300c\u9727\u306e\u8db3\u8de1\u300d", "hp": 520, "time": 18, "pattern": "s3_mist_nonspell", "kind": "nonspell"},
				{"name": "\u8a18\u61b6\u300c\u623b\u308a\u9053\u306e\u7af9\u5149\u300d", "hp": 650, "time": 20, "pattern": "s3_bamboo_blade", "kind": "spell"},
			],
		},
		"boss": {
			"id": "bamboo_illusionist",
			"display_name": "\u7af9\u6797\u5e7b\u8853\u5e2b",
			"cards": [
				{"name": "\u9727\u9580\u300c\u898b\u5931\u3046\u7af9\u306e\u8def\u300d", "hp": 1200, "time": 28, "pattern": "s3_mist_nonspell", "kind": "nonspell"},
				{"name": "\u5203\u7b26\u300c\u771f\u591c\u4e2d\u306e\u7af9\u5200\u300d", "hp": 1700, "time": 30, "pattern": "s3_bamboo_blade", "kind": "spell"},
				{"name": "\u8a18\u61b6\u300c\u53cd\u8ee2\u3059\u308b\u971e\u300d", "hp": 2300, "time": 32, "pattern": "s3_memory_vortex", "kind": "spell"},
				{"name": "\u591c\u7b26\u300c\u51fa\u53e3\u306a\u304d\u6697\u7af9\u300d", "hp": 3000, "time": 28, "pattern": "s3_dark_path", "kind": "spell"},
			],
		},
	},
	{
		"index": 4,
		"stage_id": "tengu_mountain_path",
		"display_name": "\u5929\u72d7\u5c71\u9053",
		"theme": "wind_and_news",
		"curve_tag": "wind_aimed_pressure",
		"boss_time": 5700,
		"waves": [
			{"time": 0, "x": 60, "y": -20, "hp": 8, "pattern": "wind", "move": "straight", "vx": 0.5, "vy": 1.8, "repeat": 5, "spacing_x": 90.0, "spacing_y": -8.0},
			{"time": 180, "x": 480, "y": 160, "hp": 10, "pattern": "wind_aimed", "move": "straight", "vx": -2.8, "vy": 0.1, "repeat": 2, "spacing_y": 40.0},
			{"time": 420, "x": 120, "y": -25, "hp": 10, "pattern": "downward", "move": "enter_and_stop", "vx": 0.0, "vy": 2.1, "repeat": 4, "spacing_x": 120.0, "move_data": {"move_time": 58}},
			{"time": 700, "x": 240, "y": 35, "hp": 32, "pattern": "ring", "move": "sine", "vx": 0.7, "vy": 0.5, "move_data": {"amplitude": 105}, "strong": true},
			{"time": 980, "x": 40, "y": -20, "hp": 7, "pattern": "wind", "move": "sine", "vx": 0.8, "vy": 1.9, "repeat": 6, "spacing_x": 72.0, "move_data": {"amplitude": 38}},
			{"time": 1280, "x": 240, "y": -20, "hp": 30, "pattern": "wind_aimed", "move": "enter_and_stop", "vx": 0.0, "vy": 2.0, "move_data": {"move_time": 72}, "strong": true},
			{"time": 1620, "x": 80, "y": 40, "hp": 14, "pattern": "spiral", "move": "circle", "vx": 0.0, "vy": 0.0, "repeat": 2, "spacing_x": 320.0, "move_data": {"center_x": 100, "center_y": 90, "radius": 55}},
			{"time": 1980, "x": -20, "y": 220, "hp": 12, "pattern": "wind", "move": "straight", "vx": 3.0, "vy": -0.1, "repeat": 2, "spacing_x": 520.0, "variants": [{"vx": 3.0}, {"vx": -3.0}]},
			{"time": 2380, "x": 100, "y": -25, "hp": 11, "pattern": "double_spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.8, "repeat": 4, "spacing_x": 95.0, "move_data": {"move_time": 74}},
			{"time": 2800, "x": 240, "y": 45, "hp": 45, "pattern": "wind_aimed", "move": "sine", "vx": 0.4, "vy": 0.4, "move_data": {"amplitude": 120}, "strong": true},
			{"time": 3300, "x": 70, "y": -20, "hp": 9, "pattern": "wind", "move": "straight", "vx": 1.2, "vy": 1.6, "repeat": 5, "spacing_x": 85.0, "spacing_y": -5.0},
			{"time": 3800, "x": 120, "y": -25, "hp": 16, "pattern": "double_spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.9, "repeat": 3, "spacing_x": 120.0, "move_data": {"move_time": 80}, "strong": true},
			{"time": 4300, "x": 240, "y": -20, "hp": 52, "pattern": "wind_aimed", "move": "enter_and_stop", "vx": 0.0, "vy": 1.7, "move_data": {"move_time": 86}, "strong": true},
			{"time": 4800, "x": 60, "y": -20, "hp": 8, "pattern": "downward", "move": "straight", "vx": 0.0, "vy": 2.0, "repeat": 8, "spacing_x": 54.0, "spacing_y": -6.0},
			{"time": 5300, "x": 240, "y": 50, "hp": 36, "pattern": "spiral", "move": "sine", "vx": 0.3, "vy": 0.4, "move_data": {"amplitude": 90}, "strong": true},
		],
		"midboss": {
			"id": "rookie_crow_tengu",
			"display_name": "\u65b0\u7c73\u70cf\u5929\u72d7",
			"cards": [
				{"name": "\u98a8\u7b26\u300c\u8a66\u3057\u306e\u65b0\u805e\u98db\u3070\u3057\u300d", "hp": 650, "time": 18, "pattern": "s4_wind_nonspell", "kind": "nonspell"},
				{"name": "\u7d19\u9762\u300c\u5c71\u8def\u306e\u901f\u5831\u300d", "hp": 820, "time": 21, "pattern": "s4_newspaper_lattice", "kind": "spell"},
			],
		},
		"boss": {
			"id": "mountain_wind_tengu",
			"display_name": "\u5c71\u98a8\u306e\u5929\u72d7",
			"cards": [
				{"name": "\u98a8\u58f0\u300c\u5c71\u9053\u3092\u585e\u3050\u901f\u5831\u300d", "hp": 1600, "time": 29, "pattern": "s4_wind_nonspell", "kind": "nonspell"},
				{"name": "\u7a81\u98a8\u300c\u4e0a\u6607\u6c17\u6d41\u306e\u8abf\u3079\u300d", "hp": 2200, "time": 31, "pattern": "s4_tengu_gale", "kind": "spell"},
				{"name": "\u7d19\u7b26\u300c\u4e71\u821e\u3059\u308b\u7248\u7d19\u300d", "hp": 2700, "time": 31, "pattern": "s4_newspaper_lattice", "kind": "spell"},
				{"name": "\u5831\u7b26\u300c\u5c71\u9802\u306e\u98a8\u53f7\u5916\u300d", "hp": 3300, "time": 28, "pattern": "s4_sky_report", "kind": "spell"},
			],
		},
	},
	{
		"index": 5,
		"stage_id": "oni_banquet_hall",
		"display_name": "\u9b3c\u4e4b\u5bb4\u5ef3",
		"theme": "drums_and_oni_fire",
		"curve_tag": "rhythm_orb_resource",
		"boss_time": 6000,
		"waves": [
			{"time": 0, "x": 90, "y": -20, "hp": 9, "pattern": "rhythm", "move": "enter_and_stop", "vx": 0.0, "vy": 2.0, "repeat": 4, "spacing_x": 100.0, "move_data": {"move_time": 58}},
			{"time": 220, "x": 60, "y": -20, "hp": 8, "pattern": "downward", "move": "straight", "vx": 0.0, "vy": 2.1, "repeat": 6, "spacing_x": 72.0, "spacing_y": -8.0},
			{"time": 500, "x": 240, "y": 40, "hp": 42, "pattern": "rhythm", "move": "sine", "vx": 0.4, "vy": 0.5, "move_data": {"amplitude": 100}, "strong": true},
			{"time": 840, "x": 120, "y": 35, "hp": 28, "pattern": "large_orb", "move": "enter_and_stop", "vx": 0.0, "vy": 1.3, "repeat": 2, "spacing_x": 240.0, "move_data": {"move_time": 70}, "strong": true},
			{"time": 1180, "x": -20, "y": 210, "hp": 12, "pattern": "rhythm", "move": "straight", "vx": 2.7, "vy": 0.0, "repeat": 2, "spacing_x": 520.0, "variants": [{"vx": 2.7}, {"vx": -2.7}]},
			{"time": 1540, "x": 240, "y": -20, "hp": 50, "pattern": "double_spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.7, "move_data": {"move_time": 82}, "strong": true},
			{"time": 1920, "x": 70, "y": -20, "hp": 10, "pattern": "rhythm", "move": "sine", "vx": 0.0, "vy": 1.8, "repeat": 5, "spacing_x": 86.0, "spacing_y": -8.0, "move_data": {"amplitude": 42}},
			{"time": 2320, "x": 240, "y": 55, "hp": 44, "pattern": "large_orb", "move": "sine", "vx": 0.2, "vy": 0.3, "move_data": {"amplitude": 70}, "strong": true},
			{"time": 2780, "x": 100, "y": -25, "hp": 13, "pattern": "spiral", "move": "enter_and_stop", "vx": 0.0, "vy": 1.9, "repeat": 4, "spacing_x": 95.0, "move_data": {"move_time": 70}},
			{"time": 3220, "x": 240, "y": 45, "hp": 58, "pattern": "rhythm", "move": "sine", "vx": 0.4, "vy": 0.4, "move_data": {"amplitude": 110}, "strong": true},
			{"time": 3700, "x": 70, "y": -20, "hp": 10, "pattern": "large_orb", "move": "enter_and_stop", "vx": 0.0, "vy": 1.2, "repeat": 3, "spacing_x": 170.0, "move_data": {"move_time": 86}, "strong": true},
			{"time": 4200, "x": 40, "y": -20, "hp": 9, "pattern": "rhythm", "move": "straight", "vx": 0.0, "vy": 1.9, "repeat": 7, "spacing_x": 68.0, "spacing_y": -6.0},
			{"time": 4700, "x": 240, "y": -20, "hp": 64, "pattern": "double_spread", "move": "enter_and_stop", "vx": 0.0, "vy": 1.6, "move_data": {"move_time": 90}, "strong": true},
			{"time": 5200, "x": 100, "y": -20, "hp": 12, "pattern": "rhythm", "move": "enter_and_stop", "vx": 0.0, "vy": 1.9, "repeat": 4, "spacing_x": 100.0, "move_data": {"move_time": 72}},
			{"time": 5600, "x": 240, "y": 50, "hp": 70, "pattern": "large_orb", "move": "sine", "vx": 0.2, "vy": 0.3, "move_data": {"amplitude": 95}, "strong": true},
		],
		"midboss": {
			"id": "little_oni_drummer",
			"display_name": "\u5c0f\u9b3c\u306e\u592a\u9f13\u624b",
			"cards": [
				{"name": "\u9f13\u58f0\u300c\u4e09\u62cd\u5b50\u306e\u9580\u300d", "hp": 780, "time": 19, "pattern": "s5_rhythm_nonspell", "kind": "nonspell"},
				{"name": "\u9f13\u7b26\u300c\u5bb4\u306e\u88cf\u6253\u3061\u300d", "hp": 980, "time": 22, "pattern": "s5_drum_vortex", "kind": "spell"},
			],
		},
		"boss": {
			"id": "banquet_oni_princess",
			"display_name": "\u5bb4\u306e\u9b3c\u59eb",
			"cards": [
				{"name": "\u9152\u58f0\u300c\u5bb4\u5ef3\u3092\u63fa\u3089\u3059\u62cd\u5b50\u300d", "hp": 1900, "time": 29, "pattern": "s5_rhythm_nonspell", "kind": "nonspell"},
				{"name": "\u9b3c\u706b\u300c\u76c3\u3092\u7167\u3089\u3059\u7d05\u96e8\u300d", "hp": 2300, "time": 31, "pattern": "s5_oni_fire", "kind": "spell"},
				{"name": "\u7389\u7b26\u300c\u5bb4\u306e\u5927\u7389\u3053\u308d\u304c\u3057\u300d", "hp": 2900, "time": 32, "pattern": "s5_large_orb_spell", "kind": "spell"},
				{"name": "\u592a\u9f13\u300c\u56de\u308b\u9b3c\u306e\u5c0f\u8def\u300d", "hp": 3300, "time": 31, "pattern": "s5_drum_vortex", "kind": "spell"},
				{"name": "\u9154\u7b26\u300c\u5c3d\u304d\u306a\u3044\u5bb4\u306e\u591c\u300d", "hp": 3800, "time": 29, "pattern": "s5_banquet_darkness", "kind": "spell"},
				{"name": "\u9b3c\u58f0\u300c\u5bb4\u5f8c\u306e\u4e8c\u5ea6\u6253\u3061\u300d", "hp": 2100, "time": 24, "pattern": "s5_rhythm_nonspell", "kind": "nonspell"},
			],
		},
	},
	{
		"index": 6,
		"stage_id": "night_festival_divine_realm",
		"display_name": "\u591c\u796d\u795e\u57df",
		"theme": "lantern_faith_domain",
		"curve_tag": "final_readable_density",
		"boss_time": 6300,
		"waves": [
			{"time": 0, "x": 80, "y": -20, "hp": 10, "pattern": "final_dense", "move": "enter_and_stop", "vx": 0.0, "vy": 2.0, "repeat": 5, "spacing_x": 80.0, "move_data": {"move_time": 60}},
			{"time": 220, "x": 240, "y": 35, "hp": 52, "pattern": "ring", "move": "sine", "vx": 0.4, "vy": 0.4, "move_data": {"amplitude": 115}, "strong": true},
			{"time": 520, "x": 60, "y": -20, "hp": 9, "pattern": "wind", "move": "straight", "vx": 0.6, "vy": 1.9, "repeat": 6, "spacing_x": 72.0, "spacing_y": -6.0},
			{"time": 860, "x": 240, "y": 45, "hp": 58, "pattern": "large_orb", "move": "enter_and_stop", "vx": 0.0, "vy": 1.1, "move_data": {"move_time": 82}, "strong": true},
			{"time": 1220, "x": 100, "y": -20, "hp": 12, "pattern": "final_dense", "move": "sine", "vx": 0.0, "vy": 1.8, "repeat": 4, "spacing_x": 95.0, "move_data": {"amplitude": 50}},
			{"time": 1640, "x": -20, "y": 190, "hp": 14, "pattern": "wind_aimed", "move": "straight", "vx": 3.0, "vy": 0.0, "repeat": 2, "spacing_x": 520.0, "variants": [{"vx": 3.0}, {"vx": -3.0}]},
			{"time": 2060, "x": 240, "y": 50, "hp": 66, "pattern": "rhythm", "move": "sine", "vx": 0.3, "vy": 0.4, "move_data": {"amplitude": 125}, "strong": true},
			{"time": 2520, "x": 70, "y": -25, "hp": 11, "pattern": "spiral", "move": "enter_and_stop", "vx": 0.0, "vy": 1.8, "repeat": 5, "spacing_x": 85.0, "move_data": {"move_time": 76}},
			{"time": 3000, "x": 240, "y": 40, "hp": 72, "pattern": "final_dense", "move": "enter_and_stop", "vx": 0.0, "vy": 1.6, "move_data": {"move_time": 90}, "strong": true},
			{"time": 3500, "x": 80, "y": -20, "hp": 13, "pattern": "large_orb", "move": "enter_and_stop", "vx": 0.0, "vy": 1.1, "repeat": 3, "spacing_x": 160.0, "move_data": {"move_time": 84}, "strong": true},
			{"time": 4020, "x": 50, "y": -20, "hp": 10, "pattern": "final_dense", "move": "straight", "vx": 0.0, "vy": 1.9, "repeat": 8, "spacing_x": 60.0, "spacing_y": -5.0},
			{"time": 4560, "x": 240, "y": 55, "hp": 80, "pattern": "double_spread", "move": "sine", "vx": 0.2, "vy": 0.3, "move_data": {"amplitude": 130}, "strong": true},
			{"time": 5100, "x": 100, "y": -20, "hp": 13, "pattern": "rhythm", "move": "enter_and_stop", "vx": 0.0, "vy": 1.9, "repeat": 4, "spacing_x": 100.0, "move_data": {"move_time": 70}},
			{"time": 5600, "x": 240, "y": 50, "hp": 86, "pattern": "final_dense", "move": "sine", "vx": 0.2, "vy": 0.35, "move_data": {"amplitude": 145}, "strong": true},
			{"time": 6050, "x": 240, "y": -20, "hp": 96, "pattern": "large_orb", "move": "enter_and_stop", "vx": 0.0, "vy": 1.2, "move_data": {"move_time": 92}, "strong": true},
		],
		"midboss": {
			"id": "festival_fox_miko",
			"display_name": "\u591c\u796d\u306e\u72d0\u5deb\u5973",
			"cards": [
				{"name": "\u4fe1\u706f\u300c\u795e\u57df\u306e\u524d\u591c\u796d\u300d", "hp": 900, "time": 20, "pattern": "s6_faith_nonspell", "kind": "nonspell"},
				{"name": "\u72d0\u706b\u300c\u767e\u706f\u306e\u5c0e\u304d\u300d", "hp": 1150, "time": 23, "pattern": "s6_final_lantern_spell", "kind": "spell"},
			],
		},
		"boss": {
			"id": "hyakki_night_festival_god",
			"display_name": "\u767e\u9b3c\u591c\u796d\u795e",
			"cards": [
				{"name": "\u795e\u58f0\u300c\u767e\u9b3c\u3092\u547c\u3076\u591c\u796d\u300d", "hp": 2400, "time": 30, "pattern": "s6_faith_nonspell", "kind": "nonspell"},
				{"name": "\u706f\u7b26\u300c\u795e\u57df\u3092\u6e80\u305f\u3059\u8d64\u63d0\u706f\u300d", "hp": 3000, "time": 32, "pattern": "s6_lantern_rain", "kind": "spell"},
				{"name": "\u591c\u796d\u300c\u767e\u706f\u6700\u7d42\u7d50\u754c\u300d", "hp": 3600, "time": 34, "pattern": "s6_final_lantern_spell", "kind": "spell"},
				{"name": "\u795e\u7389\u300c\u4fe1\u4ef0\u306e\u5927\u9580\u300d", "hp": 4200, "time": 32, "pattern": "s6_hyakki_gate", "kind": "spell"},
				{"name": "\u5e38\u591c\u300c\u7d42\u308f\u3089\u306a\u3044\u796d\u56c3\u5b50\u300d", "hp": 5000, "time": 30, "pattern": "s6_festival_darkness", "kind": "spell"},
				{"name": "\u795e\u58f0\u300c\u591c\u660e\u3051\u524d\u306e\u518d\u795d\u8a00\u300d", "hp": 2700, "time": 25, "pattern": "s6_faith_nonspell", "kind": "nonspell"},
			],
		},
	},
]

func stage_count() -> int:
	return STAGES.size()

func stages() -> Array:
	var result: Array = []
	for stage in STAGES:
		result.append(stage_config(int(stage.get("index", 0))))
	return result

func pattern_aliases() -> Dictionary:
	return PATTERN_ALIASES.duplicate(true)

func stage_config(stage_index: int) -> Dictionary:
	var stage := _stage_entry(stage_index)
	if stage.is_empty():
		return {}
	return {
		"index": int(stage.index),
		"stage_id": String(stage.stage_id),
		"display_name": String(stage.display_name),
		"theme": String(stage.theme),
		"curve_tag": String(stage.curve_tag),
		"boss_time": int(stage.boss_time),
		"midboss_id": String(stage.midboss.id),
		"boss_id": String(stage.boss.id),
	}

func wave_schedule(stage_index: int) -> Array:
	var stage := _stage_entry(stage_index)
	if stage.is_empty():
		return []
	return stage.waves.duplicate(true)

func midboss_definition(stage_index: int) -> Dictionary:
	var stage := _stage_entry(stage_index)
	if stage.is_empty():
		return {}
	return stage.midboss.duplicate(true)

func boss_definition(stage_index: int) -> Dictionary:
	var stage := _stage_entry(stage_index)
	if stage.is_empty():
		return {}
	return stage.boss.duplicate(true)

func boss_cards(stage_index: int) -> Array:
	var boss := boss_definition(stage_index)
	if boss.is_empty():
		return []
	return boss.get("cards", []).duplicate(true)

func _stage_entry(stage_index: int) -> Dictionary:
	for stage in STAGES:
		if int(stage.get("index", 0)) == stage_index:
			return stage
	return {}
