# M1 战斗内容设计冻结

> 冻结基线：`b1b5e66a4482321435ceebc4d25870c1b3a542fb`。本文只冻结已批准 Windows 1.0 v3 的六关战斗内容，不改写总体计划、里程碑、Agent 政策或 readiness ledger；难度仅有 Normal / Hard。

## 身份与范围

六个地点、六名中Boss、六名Boss与原故事前提保持不变：`shrine_approach`（神社参道，`lantern_tsukumogami` / `festival_guide_fox`）、`yokai_market`（妖怪市集，`abacus_tsukumogami` / `oni_market_leader`）、`mist_bamboo_grove`（迷雾竹林，`lost_rabbit_yokai` / `bamboo_illusionist`）、`tengu_mountain_path`（天狗山道，`rookie_crow_tengu` / `mountain_wind_tengu`）、`oni_banquet_hall`（鬼之宴厅，`little_oni_drummer` / `banquet_oni_princess`）、`night_festival_divine_realm`（夜祭神域，`festival_fox_miko` / `hyakki_night_festival_god`）。没有新增主角、地点、难度或 Extra Stage。

## 六关升级与关卡路线

| 关 | 固定身份 | 三个 combat segment | 实战中Boss位置 | Boss 前高潮 | Hard 结构拓扑 | 高分路线 |
|---|---|---|---|---|---|---|
| 1 神社参道 | 提灯队列／自机狙诱导／横穿回返／高收点 | 提灯点名 → 诱导参拜 → 回灯前庭 | beat 6 后入场；完整打 `stage_1_midboss_nonspell_1` 与 `stage_1_midboss_spell_1` | beat 18「十字回灯大收束」 | 单缺口分叉为上下支，下一拍交叉重接成 S 路；回返边由对边变相邻边 | 每列最后一灯熄灭后 90 帧内越过 `y=240`，取得高收点与 seal |
| 2 妖怪市集 | 算盘反弹／摊位巷／击破顺序 | 开市算账 → 摊巷竞价 → 收市钟序 | beat 6 后；横列 nonspell 加反弹珠 spell | beat 18「三摊收市连锁」 | 击破节点翻转邻摊旗、侧面反弹重接巷道；错误选择改变图而非加速 | 按公开价格 3→2→1 击破，并擦过每枚一次反弹珠维持 `price_chain` |
| 3 迷雾竹林 | 可见延迟弹／后像记忆路线／零隐形碰撞 | 雾标入林 → 兔迹回忆 → 残像归路 | beat 6 后；足迹与返路竹光两相 | beat 18「四岔残像归一」 | 时间队列变为三角／圆／方的公开符号置换；旧路线按图反转或重接 | 在影弹激活前穿 graze 环并离开，连续三枚形成 `memory_chain` |
| 4 天狗山道 | 风弧／新闻格／快速横向换巷且不推玩家 | 风向测绘 → 号外横风 → 急换山脊 | beat 6 后；曲率阅读加列行交棒 | beat 18「三版号外换线」 | 版纸局部旋转、铰链重接、巷道分叉再交叉合流；风只改变弹道 | 版铃后 45 帧内横越 180px 并擦弧心，维持 `rapid_lane_chain` |
| 5 鬼之宴厅 | 固定 simulation 拍／大玉门／节奏切口 | 正拍门廊 → 宴席切分 → 复拍鬼门 | beat 6 后；三拍门与宴之反拍 | beat 18「六拍合门」 | Hard 为真正 `C3 × C2`：三拍门与两拍切口在第六拍合流，拍速不变 | 在门点 ±6 帧穿门并擦门柱，六拍全准完成 `onbeat_chain` |
| 6 夜祭神域 | 前五式结构变换与共享节点组合 | 五式召请 → 五式神乐 → 百鬼合祭 | beat 6 后；共享灯门／祭文节点加百灯 3:2 门图 | beat 18「五式一门百鬼合祭」 | 前一式选择改变后一式邻接；第六拍一次提交公开的节点置换，不复制旧弹幕后加速 | 完成高收、反弹擦弹、影环、快换巷、精准拍门五种 proof，并在 180 帧内兑换 |

每关机器数据固定 18 个 beat（允许范围 18–24）与 3 个 segment。所有非 `transition` beat 的 `max_gap_after_frames` 均不超过 180；中Boss不是叙事占位，而是有完整 HP/超时结算的两阶段实战。

## 玩家学习进程

1. 第 1 关先教“看预告后承诺路线”：读灯门、叠自机狙、只处理一次返场。
2. 第 2 关增加因果选择：玩家的击破顺序实际改变摊巷和反弹出口。
3. 第 3 关要求记忆，但所有未来危险均以无碰撞影、形状和倒计时公开；不以隐藏信息制造难度。
4. 第 4 关缩短横向决策窗口，并用旋转格重接路线；玩家位置始终只由输入控制。
5. 第 5 关把路线放进固定 60 Hz 拍钟；Hard 的 3:2 是状态乘积，不是更快的 Normal。
6. 第 6 关让旧语法编辑同一张门图：辨认规则仍有用，但必须理解它的结构转换。

## 40-phase 索引

冻结总数为 **40 phases = 26 spell + 14 nonspell**。第 1–4 关各 6 phase，第 5–6 关各 8 phase；每名中Boss保留一 nonspell 与一 spell，Boss 卡数与既有数据一致。下列 deterministic stream ID 与完整结构指纹均逐项唯一。

### Stage 1

- `stage_1_midboss_nonspell_1` — 夜灯「参道提灯列」 — **nonspell** — stream `danmaku.m1.s1.midboss.nonspell.1.v1`
  - 结构指纹：`lantern_queue|queue_project>single_open>aim_old_side>fork_reset|center>opposite_open_door>center|N:single_gap_queue|H:forked_gate_graph:middle_gap_splits_then_crosses|W:lamp_floor_projection`
- `stage_1_midboss_spell_1` — 灯符「小さな祭り火」 — **spell** — stream `danmaku.m1.s1.midboss.spell.1.v1`
  - 结构指纹：`lantern_procession|number_lamps>ring_with_wedge>extinguish_nearest>diagonal_sequence|center>nearest_extinguished_lamp>diagonal_opposite|N:ordered_wedge_procession|H:braided_wedge_order:two_orders_interleave|W:numbered_lamp_wedges`
- `stage_1_boss_nonspell_1` — 導火「狐の参道案内」 — **nonspell** — stream `danmaku.m1.s1.boss.nonspell.1.v1`
  - 结构指纹：`aimed_guidance|draw_safe_side>triple_lock>deny_old_route>central_release|center>same_side_as_old_route>opposite_player|N:guide_then_deny_old_route|H:cross_guidance_nodes:guide_line_has_cross_node|W:fox_line_then_gray_lock`
- `stage_1_boss_spell_1` — 星符「神社星雨」 — **spell** — stream `danmaku.m1.s1.boss.spell.1.v1`
  - 结构指纹：`star_rain_queue|show_three_columns>break_to_delay>two_columns_fall>edge_refill|center>delayed_column>outer_column|N:player_delays_one_column|H:column_dependency_cycle:delay_rotates_neighbor|W:column_dependency_arrows`
- `stage_1_boss_spell_2` — 蝶符「夜祭の紙蝶」 — **spell** — stream `danmaku.m1.s1.boss.spell.2.v1`
  - 结构指纹：`paper_butterfly_axles|draw_axles>half_orbit>swap_axles>tangent_exit|center>upper_axle>lower_axle|N:counter_rotating_figure_eight|H:axis_exchange_topology:axles_swap_vertical_order|W:visible_axle_and_tangent`
- `stage_1_boss_spell_3` — 結界「初夜の神罰」 — **spell** — stream `danmaku.m1.s1.boss.spell.3.v1`
  - 结构指纹：`cross_return_boundary|announce_edges>outbound_pair>cross_open>single_return_destroy|center>open_quadrant>diagonal_quadrant|N:single_return_quadrant_cycle|H:return_order_permutation:opposite_edges_become_adjacent_pair|W:edge_countdown_and_cross_shadow`

### Stage 2

- `stage_2_midboss_nonspell_1` — 算符「市集の横列」 — **nonspell** — stream `danmaku.m1.s2.midboss.nonspell.1.v1`
  - 结构指纹：`abacus_parity_rows|color_parity>odd_rebound>break_cancels>even_opens_neighbor|center>slow_parity_column>open_lane|N:odd_even_row_release|H:parity_lane_swap:odd_kill_swaps_even_exit|W:parity_frames_and_rebound_tail`
- `stage_2_midboss_spell_1` — 珠符「跳ねるそろばん玉」 — **spell** — stream `danmaku.m1.s2.midboss.spell.1.v1`
  - 结构指纹：`abacus_rebound_ladder|light_rungs>outer_bounce>inner_bounce>breakable_lower_gap|center>upper_rung_end>lower_gap|N:alternating_rebound_ladder|H:rung_to_booth_reflection:middle_rung_redirects_to_side_wall|W:rung_future_path`
- `stage_2_boss_nonspell_1` — 市符「妖市の値切り」 — **nonspell** — stream `danmaku.m1.s2.boss.nonspell.1.v1`
  - 结构指纹：`price_kill_order|show_prices>highest_closes_neighbor>kill_flips_flags>survivor_sets_exit|center>highest_price_booth>surviving_exit|N:public_three_target_order|H:neighbor_flag_flip:kill_flips_adjacent_target|W:price_and_causal_lane_flash`
- `stage_2_boss_spell_1` — 泡符「銅貨の泡涌き」 — **spell** — stream `danmaku.m1.s2.boss.spell.1.v1`
  - 结构指纹：`coin_bubble_exchange|number_two_layers>outer_rebounds_in>bell_releases_inner>swap_roles|center>outer_gap>inner_gap|N:two_layer_exchange|H:three_booth_exchange_cycle:layers_become_three_cycle|W:numbered_exchange_arrows`
- `stage_2_boss_spell_2` — 道具「迷子の道具屋」 — **spell** — stream `danmaku.m1.s2.boss.spell.2.v1`
  - 结构指纹：`booth_inventory_maze|declare_inventory>fill_ghost_grid>break_removes_and_rotates>two_booths_form_exit|center>chosen_booth_diagonal>remaining_exit|N:choose_one_of_three_walls|H:inventory_dependency_maze:chosen_booth_rotates_neighbor|W:ghost_inventory_no_collision`
- `stage_2_boss_spell_3` — 鏡符「計り直しの水鏡」 — **spell** — stream `danmaku.m1.s2.boss.spell.3.v1`
  - 结构指纹：`water_mirror_remeasure|run_source>record_ghost>flip_into_neighbor>swap_source_copy|center>mirror_axis_end>copied_lane|N:record_then_adjacent_mirror|H:mirror_axis_choice:player_kill_selects_axis|W:mirror_full_path_preview`

### Stage 3

- `stage_3_midboss_nonspell_1` — 迷符「霧の足跡」 — **nonspell** — stream `danmaku.m1.s3.midboss.nonspell.1.v1`
  - 结构指纹：`numbered_footprint_activation|show_all_footprints>activate_one_lock>afterimage_gate>activate_three_clear|center>footprint_1>footprint_3|N:activation_in_spawn_order|H:symbol_group_order:shape_order_not_time_order|W:number_shape_countdowns`
- `stage_3_midboss_spell_1` — 記憶「戻り道の竹光」 — **spell** — stream `danmaku.m1.s3.midboss.spell.1.v1`
  - 结构指纹：`reverse_bamboo_memory|preview_forward>flip_arrow>activate_reverse>afterimage_next_corridor|center>blade_destination>next_source|N:preview_forward_activate_reverse|H:paired_reverse_corridors:two_paths_reverse_in_opposite_order|W:full_reverse_path_preview`
- `stage_3_boss_nonspell_1` — 霧門「見失う竹の路」 — **nonspell** — stream `danmaku.m1.s3.boss.nonspell.1.v1`
  - 结构指纹：`fog_gate_selection|project_three_routes>publish_symbol>wrong_gates_countdown>correct_gate_window|center>wrong_gate_decoy>correct_gate_opposite|N:public_correct_gate|H:route_symbol_rotation:correct_symbol_rotates_positions|W:all_gate_paths_visible`
- `stage_3_boss_spell_1` — 刃符「真夜中の竹刀」 — **spell** — stream `danmaku.m1.s3.boss.spell.1.v1`
  - 结构指纹：`bamboo_slash_afterimage|draw_axis>slash_pass>rotate_afterimage>spawn_from_opposite_end|center>axis_end_A>axis_end_B|N:slash_then_rotate_afterimage|H:alternating_rotation_sign:rotation_sign_follows_symbol|W:axis_and_rotation_symbol`
- `stage_3_boss_spell_2` — 記憶「反転する霞」 — **spell** — stream `danmaku.m1.s3.boss.spell.2.v1`
  - 结构指纹：`memory_vortex_permutation|show_graph>record_visit>commit_memory>reverse_visited_edges|center>unvisited_node>reversed_edge_midpoint|N:visited_edges_reverse|H:two_visit_permutation:two_nodes_swap_neighbors|W:graph_preview_before_activation`
- `stage_3_boss_spell_3` — 夜符「出口なき暗竹」 — **spell** — stream `danmaku.m1.s3.boss.spell.3.v1`
  - 结构指纹：`dark_bamboo_false_exit|show_close_ticks>close_three>afterimage_marks_last>center_reopens|center>latest_exit>center_reopen|N:four_visible_close_times|H:close_order_from_previous_route:next_order_is_previous_cross_order|W:door_numeric_countdowns`

### Stage 4

- `stage_4_midboss_nonspell_1` — 風符「試しの新聞飛ばし」 — **nonspell** — stream `danmaku.m1.s4.midboss.nonspell.1.v1`
  - 结构指纹：`wind_arc_lane_test|preview_blue_arc>open_concavity>counter_arc_handoff>grid_closes_old_lane|center>blue_concavity>gold_concavity|N:alternating_arc_concavity|H:dual_curvature_overlap:opposite_arcs_share_transfer_window|W:curvature_center_and_lane_arrow`
- `stage_4_midboss_spell_1` — 紙面「山路の速報」 — **spell** — stream `danmaku.m1.s4.midboss.spell.1.v1`
  - 结构指纹：`headline_row_column_handoff|preview_columns>columns_fire_and_clear>rows_take_over>arc_points_to_corner|center>column_gap>row_gap_corner|N:column_to_row_window|H:grid_quarter_rotation:panels_rotate_and_reconnect|W:old_and_new_grid_overlap_preview`
- `stage_4_boss_nonspell_1` — 風声「山道を塞ぐ速報」 — **nonspell** — stream `danmaku.m1.s4.boss.nonspell.1.v1`
  - 结构指纹：`headline_chicane|open_first_chicane>rear_arc_closes>open_second_chicane>clear_overlap|center>left_chicane>right_chicane|N:two_panel_chicane|H:branching_chicane_merge:first_panel_forks_second_merges|W:full_chicane_preview`
- `stage_4_boss_spell_1` — 突風「上昇気流の調べ」 — **spell** — stream `danmaku.m1.s4.boss.spell.1.v1`
  - 结构指纹：`updraft_arc_staves|draw_staff_notes>fire_occupied_lines>change_clef>empty_line_jumps|center>low_empty_staff>high_empty_staff|N:one_empty_staff_lane|H:staff_clef_permutation:clef_reorders_nonadjacent_lanes|W:clef_lane_mapping`
- `stage_4_boss_spell_2` — 紙符「乱舞する版紙」 — **spell** — stream `danmaku.m1.s4.boss.spell.2.v1`
  - 结构指纹：`rotating_print_plates|show_plates_axes>rotate_plate_one>rotate_two_three>axis_lock_reconnects|center>plate_1_corner>plate_3_corner|N:sequential_plate_rotation|H:independent_rotation_axes:plate_two_rotates_about_shared_corner|W:post_rotation_outline`
- `stage_4_boss_spell_3` — 報符「山頂の風号外」 — **spell** — stream `danmaku.m1.s4.boss.spell.3.v1`
  - 结构指纹：`summit_front_page|publish_lane_order>left_page_turn>middle_copies_if_alive>right_core_reveal|center>left_core>middle_core>right_core|N:left_middle_right_frontpage|H:page_order_branch:middle_page_choice_sets_final_side|W:frontpage_sequence_and_copy_shadow`

### Stage 5

- `stage_5_midboss_nonspell_1` — 鼓声「三拍子の門」 — **nonspell** — stream `danmaku.m1.s5.midboss.nonspell.1.v1`
  - 结构指纹：`three_beat_orb_gate|show_meter>open_left>open_center>open_right_reset|center>left_gate>center_gate>right_gate|N:three_gate_waltz|H:three_two_overlay:two_beat_cut_over_three_gates|W:fixed_tick_beat_lamps`
- `stage_5_midboss_spell_1` — 鼓符「宴の裏打ち」 — **spell** — stream `danmaku.m1.s5.midboss.spell.1.v1`
  - 结构指纹：`offbeat_drum_cuts|preview_ring>activate_with_gap>offbeat_flip>rotate_axis_120|center>offbeat_gap>rotated_gap|N:strong_ring_offbeat_gap|H:three_two_gap_product:gap_rotates_three_while_cut_flips_two|W:dual_phase_meter`
- `stage_5_boss_nonspell_1` — 酒声「宴廳を揺らす拍子」 — **nonspell** — stream `danmaku.m1.s5.boss.nonspell.1.v1`
  - 结构指纹：`banquet_table_meter|publish_four_tables>close_current_edge>cup_selects_next>flip_all_reset|center>chosen_table_side>opposite_table|N:player_selects_next_table_gap|H:adjacent_table_rotation:choice_rotates_neighbor_gap|W:table_edge_and_dependency_arrow`
- `stage_5_boss_spell_1` — 鬼火「盃を照らす紅雨」 — **spell** — stream `danmaku.m1.s5.boss.spell.1.v1`
  - 结构指纹：`goblet_fire_rain|show_goblets>rain_into_cup>tangent_fire>break_connects_neighbors|center>empty_goblet>connected_tangent|N:three_goblet_tangents|H:goblet_edge_contraction:broken_node_connects_neighbors|W:goblet_tangent_preview`
- `stage_5_boss_spell_2` — 玉符「宴の大玉ころがし」 — **spell** — stream `danmaku.m1.s5.boss.spell.2.v1`
  - 结构指纹：`rolling_orb_gate|show_gate_graph>open_adjacent>rotate_connection>diagonal_window_reset|center>adjacent_gate>diagonal_gate|N:rotating_four_gate_cycle|H:gate_matching_alternation:adjacent_and_cross_matchings_alternate|W:matching_preview_no_push`
- `stage_5_boss_spell_3` — 太鼓「回る鬼の小路」 — **spell** — stream `danmaku.m1.s5.boss.spell.3.v1`
  - 结构指纹：`rotating_drum_alley|show_two_rings>inner_flips>outer_rotates>sixth_beat_aligns|center>inner_gap>outer_gap|N:two_ring_same_four_meter|H:true_three_two_alley:inner_flip2_outer_rotate3|W:six_cell_phase_table`
- `stage_5_boss_spell_4` — 酔符「尽きない宴の夜」 — **spell** — stream `danmaku.m1.s5.boss.spell.4.v1`
  - 结构指纹：`endless_toast_memory|show_table_graph>record_crossed_edge>commit_toast>fog_closes_neighbors|center>unvisited_table>remembered_edge|N:last_edge_protects_itself|H:two_edge_memory_graph:last_two_edges_define_only_exit|W:numbered_edge_memory`
- `stage_5_boss_nonspell_2` — 鬼声「宴後の二度打ち」 — **nonspell** — stream `danmaku.m1.s5.boss.nonspell.2.v1`
  - 结构指纹：`double_strike_coda|show_two_hit_meter>primary_records_side>secondary_opposite>swap_inner_outer|center>primary_inner_gate>secondary_outer_gate|N:two_hits_opposite_gates|H:second_hit_route_transform:secondary_uses_clockwise_not_opposite|W:gold_cyan_double_meter`

### Stage 6

- `stage_6_midboss_nonspell_1` — 信灯「神域の前夜祭」 — **nonspell** — stream `danmaku.m1.s6.midboss.nonspell.1.v1`
  - 结构指纹：`transformed_lantern_grid_nodes|show_triangle_graph>rotate_nodes>scripture_fires_edges>contract_broken_node|center>rotated_node>contracted_edge|N:lantern_queue_becomes_triangle_graph|H:shared_node_contraction:break_node_reconnects_remaining_edges|W:node_and_edge_poststate_preview`
- `stage_6_midboss_spell_1` — 狐火「百灯の導き」 — **spell** — stream `danmaku.m1.s6.midboss.spell.1.v1`
  - 结构指纹：`hundred_lantern_portal_meter|show_portal_meter>rotate_entries>flip_exit_colors>sixth_beat_choice_swap|center>chosen_entry>future_exit|N:portal_exit_follows_public_meter|H:choice_conditioned_portal_swap:previous_entry_swaps_next_exits|W:stateful_portal_preview`
- `stage_6_boss_nonspell_1` — 神声「百鬼を呼ぶ夜祭」 — **nonspell** — stream `danmaku.m1.s6.boss.nonspell.1.v1`
  - 结构指纹：`five_grammar_call_sequence|show_five_order>rotate_and_choose>preview_and_reconnect>beat_commits_graph|center>current_grammar_node>next_grammar_node|N:serial_property_transform|H:three_grammar_transaction:three_changes_commit_together|W:old_new_gate_graph`
- `stage_6_boss_spell_1` — 灯符「神域を満たす赤提灯」 — **spell** — stream `danmaku.m1.s6.boss.spell.1.v1`
  - 结构指纹：`red_lantern_graph_rain|show_rain_nodes>rain_builds_edges>kill_deletes_reverses>cross_unique_exit|center>rain_node>white_exit|N:rain_creates_directed_edges|H:edge_reversal_on_kill:delete_one_reverse_successor|W:directed_graph_postkill_preview`
- `stage_6_boss_spell_2` — 夜祭「百灯最終結界」 — **spell** — stream `danmaku.m1.s6.boss.spell.2.v1`
  - 结构指纹：`hundred_lantern_causal_boundary|announce_returns>return_enters_portal>afterimage_records_exit>rotate_next_quadrant|center>return_entry_quadrant>causal_exit_quadrant|N:return_sets_next_quadrant|H:two_return_causal_braid:two_entries_swap_future_quadrants|W:causal_quadrant_preview`
- `stage_6_boss_spell_3` — 神玉「信仰の大門」 — **spell** — stream `danmaku.m1.s6.boss.spell.3.v1`
  - 结构指纹：`faith_orb_shared_gate|show_matching>bead_traverses_edge>kill_contracts_node>sixth_beat_commits|center>chosen_orb_node>matched_exit>faith_center|N:five_node_matching|H:matching_plus_three_two_commit:node_contraction_commits_on_sixth|W:queued_matching_poststate`
- `stage_6_boss_spell_4` — 常夜「終わらない祭囃子」 — **spell** — stream `danmaku.m1.s6.boss.spell.4.v1`
  - 结构指纹：`eternal_festival_graph_memory|show_history_graph>fire_reachable_arcs>proof_deletes_edge>rotate_safe_tree|center>unused_grammar_node>safe_tree_root|N:delete_one_grammar_edge_per_round|H:history_edge_symmetric_difference:current_choice_xor_previous_choice|W:old_choice_xor_preview`
- `stage_6_boss_nonspell_2` — 神声「夜明け前の再祝言」 — **nonspell** — stream `danmaku.m1.s6.boss.nonspell.2.v1`
  - 结构指纹：`dawn_reprise_transform|show_reverse_proofs>open_last_proof_node>kill_transforms_next>dawn_arc_exit|center>last_proof_node>first_proof_node>dawn_exit|N:reverse_proof_reprise|H:run_history_reprise:actual_proof_order_reversed|W:full_reverse_run_history`

结构指纹的 canonical input 顺序是：grammar → 带角色的 emitter composition → ordered timeline events → Boss movement graph → Normal topology → Hard transformation → warning contract。phase ID、显示名、角色名、弹数、弹速、HP 与 timeout 被明确排除，因此改名、加弹或加速无法伪造新指纹。

## 共享低层 emitter

以下是全部共享 primitive；没有未登记的共享 emitter。它们只负责低层运动，完整 spell 的节点/边关系、事件顺序、Boss 移动、Normal 决策、Hard 拓扑与预告契约都不同，所以共享 primitive 不等于共享完整结构。

| primitive | 使用 phase 数 | 使用 phase IDs | 低层契约 | 可见预告 |
|---|---:|---|---|---|
| `lane_fan` | 9 | stage_1_midboss_nonspell_1<br>stage_1_midboss_spell_1<br>stage_1_boss_nonspell_1<br>stage_1_boss_spell_1<br>stage_1_boss_spell_3<br>stage_2_midboss_spell_1<br>stage_3_boss_nonspell_1<br>stage_5_boss_spell_1<br>stage_6_boss_spell_1 | 从锚点沿限定扇区直线飞行；扇区由 phase 组合决定 | 发射扇区先以同色无碰撞边线描画 |
| `aim_lock` | 5 | stage_1_midboss_nonspell_1<br>stage_1_boss_nonspell_1<br>stage_1_boss_spell_2<br>stage_3_midboss_nonspell_1<br>stage_4_boss_spell_2 | 锁定完成后固定方向直线飞行，不继续追踪玩家 | 红色锁定线收束后变灰，变灰 tick 即固定方向 |
| `return_line` | 2 | stage_1_boss_spell_3<br>stage_6_boss_spell_2 | 直线出界后仅沿已显示轨迹返场一次，第二次出界销毁 | 场边倒计时珠和同色虚线路径持续到返场 |
| `rebound_bead` | 7 | stage_2_midboss_nonspell_1<br>stage_2_midboss_spell_1<br>stage_2_boss_nonspell_1<br>stage_2_boss_spell_1<br>stage_2_boss_spell_3<br>stage_6_boss_nonspell_1<br>stage_6_boss_spell_3 | 接触唯一标记边或门后改变一次路线，第二次接触销毁 | 可触发边/门与未来 120px 路线以同色闪烁 |
| `delayed_seed` | 13 | stage_2_boss_spell_2<br>stage_2_boss_spell_3<br>stage_3_midboss_nonspell_1<br>stage_3_midboss_spell_1<br>stage_3_boss_nonspell_1<br>stage_3_boss_spell_1<br>stage_3_boss_spell_2<br>stage_3_boss_spell_3<br>stage_5_boss_spell_4<br>stage_6_midboss_spell_1<br>stage_6_boss_nonspell_1<br>stage_6_boss_spell_2<br>stage_6_boss_spell_4 | 预告态无碰撞；倒计时结束的同一 simulation tick 显形并启用碰撞 | 形状徽记、倒计时环和 18 帧颜色渐变同时显示 |
| `wind_arc` | 8 | stage_4_midboss_nonspell_1<br>stage_4_midboss_spell_1<br>stage_4_boss_nonspell_1<br>stage_4_boss_spell_1<br>stage_4_boss_spell_3<br>stage_5_boss_spell_1<br>stage_6_boss_spell_4<br>stage_6_boss_nonspell_2 | 沿已显示弧心与曲率作圆弧运动，不向玩家施加外力 | 弧心、旋向箭头和未来四分之一弧先显示 |
| `grid_edge` | 17 | stage_1_boss_spell_1<br>stage_2_midboss_nonspell_1<br>stage_2_boss_nonspell_1<br>stage_2_boss_spell_2<br>stage_3_midboss_spell_1<br>stage_3_boss_spell_1<br>stage_3_boss_spell_3<br>stage_4_midboss_nonspell_1<br>stage_4_midboss_spell_1<br>stage_4_boss_nonspell_1<br>stage_4_boss_spell_2<br>stage_4_boss_spell_3<br>stage_5_midboss_spell_1<br>stage_5_boss_spell_3<br>stage_6_midboss_nonspell_1<br>stage_6_boss_spell_1<br>stage_6_boss_spell_4 | 仅沿预告格边生成直线弹，格框本身无碰撞 | 完整无碰撞格框在发弹前描画 |
| `rhythm_pulse` | 13 | stage_1_midboss_spell_1<br>stage_2_boss_spell_1<br>stage_3_boss_spell_2<br>stage_4_boss_spell_1<br>stage_5_midboss_nonspell_1<br>stage_5_midboss_spell_1<br>stage_5_boss_nonspell_1<br>stage_5_boss_spell_2<br>stage_5_boss_spell_3<br>stage_5_boss_nonspell_2<br>stage_6_midboss_spell_1<br>stage_6_boss_spell_3<br>stage_6_boss_nonspell_2 | 以固定 simulation tick 拍钟生成环或扇，不读取音频播放位置 | 拍灯、缩圈和拍号计数共同标记下一拍 |
| `orb_gate` | 6 | stage_5_midboss_nonspell_1<br>stage_5_boss_nonspell_1<br>stage_5_boss_spell_2<br>stage_5_boss_spell_4<br>stage_5_boss_nonspell_2<br>stage_6_boss_spell_3 | 大玉作为固定门柱；门状态只改变通行邻接，不推动玩家 | 将开放门柱由紫转白并显示门号 |
| `butterfly_pair` | 1 | stage_1_boss_spell_2 | 成对纸蝶围绕各自轴线半周后沿切线离场 | 轴心和离场切线以淡粉轨迹显示 |
| `portal_lantern` | 6 | stage_6_midboss_nonspell_1<br>stage_6_midboss_spell_1<br>stage_6_boss_nonspell_1<br>stage_6_boss_spell_1<br>stage_6_boss_spell_2<br>stage_6_boss_nonspell_2 | 进入标号灯门后从同色出口出现一次，再按出口箭头直线离场 | 入口、出口和一次性连接由同色光索显示 |

## 公平性与可读性冻结

- 实际 authored 预告下限是 Normal **18 帧**、Hard **12 帧**，高于验收底线 Normal 12 / Hard 8。第 1–3 关为 30/18，第 4–5 关为 24/16，第 6 关为 18/12。
- 所有 delayed activation 都有形状或编号、倒计时环与至少 18 帧颜色渐变；预告态碰撞关闭，显形与碰撞在同一 simulation tick 启用。
- 所有 turn / rebound / portal 都画出触发边、未来路径或入口—出口光索；一次回返和一次反弹在第二次出界/接触时销毁。
- 所有 route activation 都显示完整的 old/new 图、旋向箭头、门号或目标巷；Hard 的变化必须能在弹出现前从图上读出。
- 数据中没有加速度 phase；后续 runtime 若引入 acceleration，必须在本卡之外先新增具体颜色渐变和速度矢量预告，不能静默实现。
- Stage 4 风与 Stage 5 大玉只改变弹道或门邻接，`player_external_force` 必须恒为 0；任何推玩家实现都违背冻结。
- 节奏一律以 60 Hz simulation tick 判定；音频仅作提示。暂停、帧率波动或音频 seek 不得改变拍相位。

## Stage 6 结构转换索引

| phase | 被转换的旧语法 | 新结构 |
|---|---|---|
| `stage_6_midboss_nonspell_1` | stage_1_lantern_queue<br>stage_4_newsprint_grid | 把平移队列转换成旋转三节点图；把整行/整列封锁转换成节点之间的可达边。 |
| `stage_6_midboss_spell_1` | stage_1_lantern_queue<br>stage_2_abacus_rebound<br>stage_5_polyrhythm | 提灯缺口成为入口节点；算盘镜面反弹成为一次跨门传送；3:2 拍不加速而置换入口/出口匹配。 |
| `stage_6_boss_nonspell_1` | stage_1_lantern_queue<br>stage_2_abacus_rebound<br>stage_3_afterimage_memory<br>stage_4_newsprint_grid<br>stage_5_polyrhythm | 五种规则不原样叠加，而依次编辑同一个共享门图的节点、出口、预览边、可达边与提交时机。 |
| `stage_6_boss_spell_1` | stage_1_lantern_queue<br>stage_4_newsprint_grid | 提灯队列的缺口改造成可击破选择；报纸格的行列封锁改造成由落灯生成的有向边图。 |
| `stage_6_boss_spell_2` | stage_1_cross_return<br>stage_3_afterimage_memory | Stage 1 的原路回返经门后不再原路循环；Stage 3 后像从路径记忆转换为下一象限的因果状态。 |
| `stage_6_boss_spell_3` | stage_2_abacus_rebound<br>stage_5_orb_gate<br>stage_5_polyrhythm | 算盘的一次反弹成为门图边；固定大玉从左右门变成五节点匹配；3:2 拍控制重接提交而非提升速度。 |
| `stage_6_boss_spell_4` | stage_1_lantern_queue<br>stage_2_abacus_rebound<br>stage_3_afterimage_memory<br>stage_4_newsprint_grid<br>stage_5_polyrhythm | 把五关技巧的完成记录变成可见图历史；Hard 用历史对称差改变邻接，绝非把五种弹幕复制后加速。 |
| `stage_6_boss_nonspell_2` | stage_1_lantern_queue<br>stage_2_abacus_rebound<br>stage_3_afterimage_memory<br>stage_4_newsprint_grid<br>stage_5_polyrhythm | 不复刻旧 phase；将玩家实际 proof 获取顺序变成倒序门图，五式只作为节点变换规则依次执行。 |

## 后续 runtime ticket 必须提供的行为证据

1. **身份与装载**：逐项加载 40 个 ID，保持 owner、encounter slot、26/14 split、phase 顺序与 deterministic stream ID；所有 stream 必须从 run seed 派生且可回放。
2. **事件与移动 trace**：每 phase 输出 emitter start/interval/loop、四个 ordered timeline tick、Boss 三段移动的 from/to/duration；实测 tick 与卡片一致。
3. **预告—碰撞成对证据**：对 delayed、turn、rebound、portal、route activation 记录 warning start、commit/activation 与 collision enable tick；证明下限和零隐形碰撞。
4. **Normal/Hard 拓扑断言**：以节点/边或可达巷集合比较两难度。Hard 必须命中卡片中的 graph change，不能只比较数量或速度。
5. **关卡行为回放**：每关跑完 18 beat，证明 3 segment、实战中Boss、Boss-front climax 与非 transition 最大战斗空档 180 帧。
6. **得分路线证据**：记录 Stage 1 收点窗、Stage 2 kill order、Stage 3 warning/activation、Stage 4 lane delta、Stage 5 beat delta、Stage 6 proof token 的来源 tick 与奖励结算。
7. **特殊不变量**：Stage 3 预告态 collision disabled；Stage 4/5 `player_external_force == 0`；Stage 5 拍钟只由 simulation tick 前进；每枚 return/rebound 的 UID 只能转向一次。
8. **Stage 6 转换证据**：输出每轮 old graph、选择/历史、new graph，并证明其是旋转、收缩、匹配、置换或 XOR，而非调用前五关 alias 后增加弹数/速度。

## 尚未由本 ticket 消除的风险

本冻结是内容与机器契约，不包含 runtime 翻译、碰撞实现、音画偏差测量、Windows 60 FPS 压测或最终手感调参。尤其需在后续实现中验证：720×960 场地上的实际空隙宽度、Boss 路径不与预告重叠、3:2 音效与 simulation tick 的可感知同步，以及 Stage 6 图预览在高密度画面仍可读。任何调参不得改变这里冻结的 phase 身份、事件顺序、Hard 拓扑或得分决策。
