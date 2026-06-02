extends Node
# DialogueDB — data + engine for the Daggerfall-style topic conversation system.
# See docs/dialogue_system_plan.md. Registered as an autoload (DialogueDB).
#
# Content lives in TOPICS / NPC_PROFILES / CITY_RUMORS below (hand-authored).
# The UI (DialogueUI) calls the engine API in the lower half of this file; it never
# touches the data dicts directly.
#
# Conditions/effects reuse the EventDeckSystem vocabulary so authoring is consistent:
#   conditions: flag_true, flag_false, has_item, rep_gte:[faction,n], rep_lte:[faction,n],
#               quest_completed, has_topic
#   effects:    set_flag, add_rep, add_item, learn, start_quest, complete_quest, open_service
#
# "Work" is not a separate structure: a topic whose category is "work" simply appears under the
# Work tab and usually carries a start_quest effect. One code path for everything askable.

# ── Topic catalogue ─────────────────────────────────────────────────
# category: person|thing|location|work  (drives which tab the keyword shows under)
# starts_known: in the codex from the start (universal small talk + faction names)
var TOPICS: Dictionary = {
	# Universal small talk — everyone can be asked these from the start.
	"false_sky":      {"category": "thing",    "label": "the false sky",        "starts_known": true},
	"toxic_rain":     {"category": "thing",    "label": "the toxic rain",       "starts_known": true},
	"faded_atrium":   {"category": "location", "label": "the Faded Atrium",     "starts_known": true},
	"linda":          {"category": "person",   "label": "Linda",                "starts_known": true},
	"system_x":       {"category": "person",   "label": "System X",             "starts_known": true},
	"wan_moa_torai":  {"category": "person",   "label": "Wan Moa Torai",        "starts_known": true},
	"gatebox":        {"category": "person",   "label": "Gatebox",              "starts_known": true},
	# Discoverable topics (taught by NPCs / quests).
	"generator":      {"category": "thing",    "label": "the generator"},
	"generator_coupling": {"category": "thing","label": "the generator coupling"},
	"lan_tap":        {"category": "thing",    "label": "the LAN tap"},
	"water_cistern":  {"category": "location", "label": "the Water Reclamation Cistern"},
	"pipe_church":    {"category": "person",   "label": "the Pipe Church"},
	"the_bar":        {"category": "location", "label": "the bar"},
	"vessel":         {"category": "person",   "label": "Vessel"},
	# Ward 7 / Comfort Annexe arc.
	"ward_7":               {"category": "location", "label": "Ward 7"},
	"the_grafts":           {"category": "thing",    "label": "the failed grafts"},
	"general_bone_dividend": {"category": "person",  "label": "General Bone Dividend"},
	# Hub work jobs (shown under the Work tab; clean labels for the keyword list).
	"hub_power_restore": {"category": "work", "label": "fixing the generator"},
	"hub_lan_restore":   {"category": "work", "label": "splicing the LAN tap"},
	"hub_cistern":       {"category": "work", "label": "the clinic water run"},
	"hub_clear_court":   {"category": "work", "label": "clearing the atrium"},
	"accept_coil_invitation": {"category": "work", "label": "Velvet Coil's hub offer"},
	"sealed_mask":       {"category": "work", "label": "a rain mask"},
	"torai_obligation":  {"category": "work", "label": "one more try"},
	"torai_salvage_contract": {"category": "work", "label": "a salvage contract"},
	"bone_dividend_lead": {"category": "work", "label": "the Bone Dividend lead"},
	# Cooters job board (Marbles).
	"collect_pay": {"category": "work", "label": "collecting your pay"},
	"cooters": {"category": "location", "label": "Cooters"},
	"the_rain_mutant": {"category": "thing", "label": "the contained rain mutant"},
}

# ── NPC dialogue profiles ───────────────────────────────────────────
# Keyed by npc_id (matches NPCDialogue.npc_id). See plan §3.3. PILOT CONTENT — Mister Static and
# Gideon are fully authored to prove the format; remaining NPCs get migrated location-by-location.
var NPC_PROFILES: Dictionary = {
	"mister_static": {
		"name": "Mister Static", "faction": "System X", "tone_pref": "blunt",
		"greetings": [
			{"conditions": {"flag_true": "ward7_quest_logged"}, "text": {
				"warm": "You came back from Ward 7 carrying something heavy. I can see it. Tell me — then take it to the Big Gates informant. They have been waiting for a reason like you.",
				"neutral": "Ward 7. I knew the building existed. I did not know what it was doing. I am not surprised. I am just quiet about it. Ask, then find the Big Gates informant.",
				"cold": "You found Ward 7. Of course you did. Say what you need, then go talk to the informant.",
			}},
			{"conditions": {"flag_true": "hub_power_restored"}, "text": {
				"warm": "The generator stopped sounding like a dying organ — partly your fault, and I mean that kindly.",
				"neutral": "Power's holding now. I stopped apologising to the generator. Talk if you need something.",
				"cold": "Lights are on. What.",
			}},
			{"text": {
				"warm": "You again. Good. Make it quick — the coupling does not babysit itself.",
				"neutral": "Make it quick. The coupling does not babysit itself.",
				"cold": "I am keeping the lights honest. Talk fast or talk to the dark.",
			}},
		],
		"topics": {
			"generator": {
				"text": [
					{"conditions": {"flag_true": "hub_power_restored"}, "text": "Stable. Runs on something more reliable than tape and optimism now. I stopped apologising to her."},
					{"text": {
						"warm": "Sagging, but I have her talked down. Tape and intention. Tape is not a plan, just optimistic adhesive.",
						"neutral": "Held together with tape and intention. Tape is not a plan, just optimistic adhesive.",
						"cold": "It runs. Barely. That is all you are getting.",
					}},
				],
				"teaches": ["generator_coupling"],
			},
			"generator_coupling": {
				"text": "Basement coupling. When it goes, the whole block smells like blue fire and regret. Keep it seated.",
			},
			"lan_tap": {
				"text": "Vessel's department, not mine. Ask the bunny once it stops sulking and starts booting.",
				"hint": "who handles the LAN",
				"requires_flag": "vessel_repaired",
			},
			"hub_power_restore": {
				"category": "work",
				"text": "The coupling is in the basement. I have been holding it together with tape for six weeks. Go fix it properly before the tape develops opinions.",
				"hint": "work that needs doing",
				"requires_flag_false": "hub_power_restored",
				"effects": [
					{"type": "start_quest", "quest": "hub_power_restore"},
					{"type": "learn", "topic": "generator_coupling"},
				],
			},
			"ward_7": {
				"text": [
					{"conditions": {"flag_true": "ward7_experiment_docs_found"}, "text": "You pulled the documentation. Then it is real and it is worse than a rumor. Gatebox's own monitoring runs through the infrastructure Big Gates compromised — the ward reports its own health, and the report is a lie. Linda's dashboard shows it green. Take what you have to the informant."},
					{"conditions": {"flag_true": "ward7_sublevel_accessed"}, "text": "You went down to the sublevel. Then you saw the math the terminals were hiding. Pods that should have people, don't. Somebody with admin access has been checking residents out like library books. The informant will want to hear it."},
					{"text": "A Gatebox Pacification Ward, up the line. Corporate calls it green — fully operational, everyone comfortable. People in the Basement say something wrong-shaped came out of it wearing pod-issue clothing. I knew it existed. I did not look closer. You should."},
				],
				"teaches": ["the_grafts", "general_bone_dividend"],
			},
			"the_grafts": {
				"text": "Weapons-grade hardware grafted onto living people before the body was ready. Incomplete conversions. The person is still partly in there — that is the part that does not let you sleep. Big Gates made them. Ward 7 is where they came from.",
				"requires_flag": "ward7_entered",
			},
			"general_bone_dividend": {
				"text": "The name at the top of the Big Gates weapons program. I do not have a face for it, only an accounting style — souls logged as inventory, conversions logged as yield. If Ward 7 was a supplier, the General is the buyer. The informant in the atrium has been chasing that thread longer than you have.",
				"requires_flag": "ward7_entered",
			},
		},
		"rumors": [
			{"text": "Heard the bar's tap finally runs and Vessel is pouring. Miracles come cheap when the water is clean.",
			 "conditions": {"flag_true": "bar_open"}},
		],
		"services": [],
		"unknown_line": {
			"warm": "Not my wheelhouse, friend. Try someone who gets paid to know.",
			"neutral": "No idea. I fix power, not gossip.",
			"cold": "Why would I know that.",
		},
	},
	"gideon": {
		"name": "Pipe Father Gideon", "faction": "System X", "tone_pref": "blunt",
		"greetings": {
			"warm":    "The pipes have been kind today. So will I be. Bring me your wasted potential and sit a while.",
			"neutral": "The Pipe Church holds. Bring me mission scrap, failed miracles, broken proofs — I feed them to the Dreaming Generator and pay in Wan Notes.",
			"cold":    "Even the patient run dry. Speak, or trade, or move along.",
		},
		"topics": {
			"pipe_church": {
				"text": "We listen to the infrastructure because nothing else down here tells the truth. The pipes remember what comes down from above.",
				"teaches": ["water_cistern"],
			},
			"wan_moa_torai": {
				"text": "Torai will invoice a miracle if you let them. Keep your debts small and your prayers quiet.",
			},
		},
		"rumors": [
			{"text": "Saint Ratchet is back among the pipes. The congregation calls it a sign. I called it maintenance. They think that is a sign too.",
			 "conditions": {"flag_true": "saint_ratchet_returned"}},
		],
		"services": ["sell"],
		"unknown_line": "The pipes did not mention that one. Neither will I.",
	},
	"vera": {
		"name": "Vera", "faction": "System X", "tone_pref": "blunt",
		"open_effects": [{"type": "heal"}],   # patches the player up the moment they walk in
		"greetings": [
			{"conditions": {"flag_true": "hub_cistern_connected"}, "text": {
				"warm": "Sit — patched. Water's clean, clinic's running, and that is partly you. I have fixed four things today that should not have needed fixing. Good day.",
				"neutral": "Hold still. There, mended. Water runs clean now; the clinic almost feels like one.",
				"cold": "Patched. The water works. Do not make a habit of arriving in pieces.",
			}},
			{"text": {
				"warm": "Sit. There — patched. You bleed less than most who come through that door, and I take it as a compliment.",
				"neutral": "Hold still. There, you are mended. Now — I still need clean water down here.",
				"cold": "Patched. The clinic is not a confession booth with bandages. What.",
			}},
		],
		"topics": {
			"water_cistern": {
				"text": [
					{"conditions": {"flag_true": "hub_cistern_connected"}, "text": "Clean water changed everything. The clinic runs, the bar runs, people stopped tasting the pipes. Thank you for that."},
					{"text": "I need clean water for the clinic. West walkway of the cistern has a junction point — run a conduit and we are connected. Do not let Torai log you there."},
				],
			},
			"hub_cistern": {
				"category": "work",
				"text": "The clinic is dry. The Water Reclamation Cistern has a junction on the west walkway — install a conduit and we have clean water. If the valve there is already bled, it is half done.",
				"hint": "work the clinic needs",
				"requires_flag_false": "hub_cistern_connected",
				"teaches": ["water_cistern"],
				"effects": [
					{"type": "start_quest", "quest": "hub_cistern"},
					{"type": "add_card", "card": "hub_cistern_exit"},
					{"type": "add_card", "card": "hub_cistern_return"},
				],
			},
		},
		"rumors": [
			{"text": "Three people asked me if we were staying. I said yes. Two of them started carrying things in from the corridor.",
			 "conditions": {"flag_true": "hub_phase_2"}},
		],
		"services": [],
		"unknown_line": "I patch bodies, not curiosities. Ask someone with cleaner hands.",
	},
	"kiki_baja": {
		# Faction Torai: her disposition tier tracks your standing with Wan Moa Torai,
		# so warm/neutral/cold double as the Torai-standing readout.
		"name": "Kiki Baja", "faction": "Wan Moa Torai", "tone_pref": "blunt",
		"greetings": {
			"warm":    "Wan Moa Torai thinks you are useful. That is its own kind of danger, but I will take useful over flagged any day.",
			"neutral": "Wan Moa Torai is watching this location. My job is to make sure that watching is all they do. So far, so good.",
			"cold":    "Torai has you down as a problem, and problems get line items. Tread lightly near anything with their tags.",
		},
		"topics": {
			"wan_moa_torai": {
				"text": {
					"warm": "They are warming to you. I would still read every contract twice and assume the warmth is also a contract.",
					"neutral": "Debt logic, all the way down. They do not hate you. They have simply not finished pricing you.",
					"cold": "You owe them attention you do not want to give. I am the reason that attention has not become a visit.",
				},
			},
			"gatebox": {
				"text": "Torai and Gatebox pretend to be rivals. They are more like two collectors arguing over the same estate.",
			},
		},
		"rumors": [
			{"text": "Torai sent a message. It is formatted as a sales letter. I am choosing to read it as a threat.",
			 "conditions": {"flag_true": "hub_phase_2"}},
		],
		"services": [],
		"unknown_line": "Not my desk. I manage one liability at a time, and right now that is you.",
	},
	"ladderboy": {
		"name": "Ladderboy", "faction": "System X", "tone_pref": "blunt",
		"greetings": [
			{"conditions": {"flag_true": "atrium_cleared"}, "text": {
				"warm": "Atrium's clear and people actually walk through it. I did not think we would reach the part where people walk through things. What do you need reached?",
				"neutral": "Atrium's open now. Vertical access workshop — the ceiling knows things the floor does not.",
				"cold": "Floor's clear. Up is still my department. Make it fast.",
			}},
			{"text": {
				"warm": "The ceiling and I are on speaking terms today. What do you need reached?",
				"neutral": "Vertical access workshop. The ceiling knows things the floor does not. I am the reason that is useful.",
				"cold": "Up is my department. Whatever you want down here, make it fast.",
			}},
		],
		"topics": {
			"faded_atrium": {
				"text": [
					{"conditions": {"flag_true": "atrium_cleared"}, "text": "Clear. People walk through it now. I did not think we would get to the part where people walk through things."},
					{"text": "Three debris piles still clog the central atrium — fell when the ceiling section failed. Clear them and the whole hub opens up."},
				],
			},
			"hub_clear_court": {
				"category": "work",
				"text": "Three debris piles in the central atrium came down with the ceiling. Move them and the hub opens up. I would do it myself, but the workshop reaches over things — it does not clear them.",
				"hint": "work in the atrium",
				"requires_flag_false": "atrium_cleared",
				"effects": [{"type": "start_quest", "quest": "hub_clear_court"}],
			},
		},
		"rumors": [],
		"services": [],
		"unknown_line": "If it is not above head height, it is not my problem.",
	},
	"vessel": {
		"name": "Vessel", "faction": "System X", "tone_pref": "blunt",
		"greetings": [
			{"conditions": {"flag_true": "bar_open"}, "text":
				"Sit, breathe, let the lower city end without your supervision for five minutes. The stools are mostly real and the rain mutant does not visit this branch. People are drinking in a place they built instead of one they fled to. I will take it. So should you."},
			{"conditions": {"flag_true": "hub_lan_restored"}, "text":
				"Archive is live. I remember enough to be useful and not enough to be sad about it. Ask."},
			{"text": {
				"warm": "Restart sequence complete. Memory lattice partial but functional. I know what needs to happen — ask.",
				"neutral": "Restart sequence complete. I know what I am and what needs to happen. Ask, and I will tell you what I can see.",
				"cold": "I am online. That is not the same as patient. What.",
			}},
		],
		"topics": {
			"lan_tap": {
				"text": [
					{"conditions": {"flag_true": "hub_lan_restored"}, "text": "Archive is live. System X has seventeen things to tell you — sixteen warnings and one joke. I have not identified which is which."},
					{"text": "The tap cable is severed. Water Reclamation Cistern, east end of the upper walkway. Splice kit, two minutes, and System X sees the lower city again. Some of what it sees will be your problem."},
				],
				"teaches": ["water_cistern"],
			},
			"the_bar": {
				"text": "This is the Cooters mall branch and I keep it. Marbles has the original; I have the one with better structural integrity and worse regulars. Sit when you like.",
				"requires_flag": "bar_open",
			},
			"system_x": {
				"text": "I am part of how System X sees down here. Pee Kid and Yoko do the worrying. I do the pouring, now.",
			},
			"hub_lan_restore": {
				"category": "work",
				"text": "The LAN tap is severed — Water Reclamation Cistern, east end of the upper walkway. Bring a splice kit. When it is live, System X sees the whole lower city again. Some of what it sees will be your problem.",
				"hint": "work that needs a splice kit",
				"requires_flag_false": "hub_lan_restored",
				"teaches": ["lan_tap", "water_cistern"],
				"effects": [
					{"type": "start_quest", "quest": "hub_lan_restore"},
					{"type": "add_card", "card": "hub_lan_exit"},
					{"type": "add_card", "card": "hub_lan_return"},
				],
			},
		},
		"rumors": [],
		"services": [],
		"unknown_line": "Outside my archive. Ask System X when the LAN is honest again.",
	},
	"velvet_coil": {
		"name": "Velvet Coil", "faction": "", "tone_pref": "polite",
		"greetings": [
			{"conditions": {"flag_true": "coil_invitation_accepted"}, "text":
				"Conditions are holding. You will find me up in the atrium once things settle. While you are here — the table is open."},
			{"conditions": {"flag_true": "coil_invitation_available"}, "text":
				"I heard the atrium is stabilising. I want a room up there for the surgical suite — conditional terms, mutual benefit, no lease. Meanwhile, the table is open."},
			{"text": {
				"warm": "The suite is conditional and the conditions are holding. Sit on the table when you want hardware.",
				"neutral": "Surgical suite. I learned this from a VHS tape, two broken androids, and one lawsuit that technically never found me.",
				"cold": "I install, I do not chat. Bring a slot and a reason.",
			}},
		],
		"topics": {
			"linda": {
				"text": "Linda's people get their implants in clean white rooms with consent forms. Mine come with a stool and a sense of humour. Pick your horror.",
			},
			"accept_coil_invitation": {
				"category": "work",
				"text": "Good. Fourth store slot, upper floor. You will find me there once things settle. In the meantime — you are already here, might as well use the table.",
				"requires_flag": "coil_invitation_available",
				"requires_flag_false": "coil_invitation_accepted",
				"effects": [
					{"type": "set_flag", "flag": "coil_met_in_tunnels", "value": true},
					{"type": "set_flag", "flag": "coil_invitation_accepted", "value": true},
				],
			},
		},
		"rumors": [],
		"services": ["cybernetics"],
		"unknown_line": "I am a surgeon, not a switchboard. Ask elsewhere.",
	},
	"brickmouth_ronnie": {
		"name": "Brickmouth Ronnie", "faction": "Wan Moa Torai", "tone_pref": "blunt",
		"greetings": {
			"warm":    "My favourite kind of customer — the kind still breathing. You want up, sharp, mean, or stitched?",
			"neutral": "You want up, sharp, mean, or stitched? I got all four. Read the label, swallow the comedown, do not bleed on the stools.",
			"cold":    "Cash or credit, no tabs, no sob stories. What do you need.",
		},
		"topics": {
			"toxic_rain": {
				"text": "Rain eats filters and people about the same speed. I sell the thing that makes you not care for an hour. Not a cure. A vacation.",
			},
		},
		"rumors": [],
		"services": ["pharmacy"],
		"unknown_line": "I deal in chemicals, not answers. Different shelf.",
	},
	"big_gates_informant": {
		"name": "Big Gates Informant", "faction": "System X", "tone_pref": "polite",
		"greetings": [
			{"conditions": {"flag_true": "bone_dividend_general_defeated"}, "text": {
				"warm": "You put the General down. I had been doing this so long I forgot what the end of a thread feels like. Thank you. We are not done — there is always more — but tonight, this counts.",
				"neutral": "The General is down and the ledger is ours. That program has a hole in it now, the exact shape of you. More will come. Tonight, this counts.",
				"cold": "General's dead. Good. Don't expect a parade. Expect the next one.",
			}},
			{"conditions": {"flag_true": "bone_dividend_quest_active"}, "text": {
				"warm": "You took the lead. Then we are in this together, and I sleep slightly better for it. Bring me whatever the General's people leave lying around.",
				"neutral": "You took the lead on the Bone Dividend. Good. Now we follow the souls up the ledger to whoever's been signing for them.",
				"cold": "You're on it. Fine. Don't get sentimental and don't get caught.",
			}},
			{"conditions": {"flag_true": "ward7_experiment_docs_found"}, "text":
				"You have the documentation. Then I am not paranoid, I am early. That data ties Ward 7's intake to a name — General Bone Dividend. Sit. Let me make this worth the weight you carried out."},
			{"conditions": {"flag_true": "ward7_terminal_destroyed"}, "text":
				"You were in Ward 7 and you smashed the terminal. I understand the impulse. I also need evidence, and you burned ours. We can still build a case — it just costs more legwork now."},
			{"conditions": {"flag_true": "ward7_entered"}, "text":
				"You've been inside Ward 7. Then you know the shape of it, even if you didn't bring the paper. Keep your voice down. I trade in the things Gatebox files under 'green.'"},
			{"text": {
				"warm": "Keep your voice down. You have honest eyes, which is rare and occasionally useful. What do you know?",
				"neutral": "Keep your voice down. I trade in the things Gatebox files under 'green.' Ask me something worth the risk.",
				"cold": "Quiet. I don't know you well enough to be careless. What.",
			}},
		],
		"topics": {
			"ward_7": {
				"text": "A Pacification Ward that reports its own health to corporate — and the report is forged. Big Gates compromised the same infrastructure Gatebox monitors through. So Linda sees green. 235 residents 'on temporary leave.' Nobody comes back from that leave the same shape they left in.",
				"teaches": ["the_grafts", "general_bone_dividend"],
			},
			"the_grafts": {
				"text": "Weapons grown out of people. Failed ones wander; viable ones get shipped. The disposal column is longer than the success column. They keep the books in Gatebox's own clean format. That detail is the one that ends conversations.",
			},
			"general_bone_dividend": {
				"text": [
					{"conditions": {"flag_true": "ward7_experiment_docs_found"}, "text": "The General is the buyer at the top of the ledger — souls logged as yield, conversions as dividend. Your documentation names the account. That's the thread. Pull it with me and we find the body it's attached to."},
					{"text": "A name in the Big Gates weapons program. No face yet — only an accounting style that treats people as inventory. Ward 7 was a supplier. The General is who it supplied. I have been chasing this longer than you have been alive down here."},
				],
			},
			"bone_dividend_lead": {
				"category": "work",
				"text": "Then it's settled. You carried the evidence out; I cross-referenced it. The dividend posts to one place — a soul-accounting vault Big Gates keeps off every map. I'm marking it on your travel routes. The General will be there, doing the books. Go close the account. Stay reachable, stay modded carefully, stay alive.",
				"hint": "the lead the informant is chasing",
				"requires_flag": "ward7_experiment_docs_found",
				"requires_flag_false": "bone_dividend_quest_active",
				"effects": [
					{"type": "set_flag", "flag": "bone_dividend_quest_active", "value": true},
					{"type": "set_flag", "flag": "bone_dividend_location_known", "value": true},
					{"type": "learn", "topic": "general_bone_dividend"},
					{"type": "add_rep", "faction": "System X", "amount": 1},
				],
			},
		},
		"rumors": [
			{"text": "Word is Big Gates sent a team back toward Ward 7. Somebody made their installation go quiet. Brave. Stupid. Same thing down here.",
			 "conditions": {"flag_true": "ward7_overseer_terminal_destroyed"}},
		],
		"services": [],
		"unknown_line": "I only know what gets people killed. That isn't on the list.",
	},
	"ward7_survivor": {
		"name": "Ward 7 Survivor", "faction": "", "tone_pref": "polite",
		"greetings": {
			"warm": "...you're the one. From the room with the lights. I don't — thank you. I don't know how to do the rest of the sentence yet.",
			"neutral": "...I'm awake. People keep telling me that like it's good news. I'm not arguing. Thank you, I think.",
			"cold": "...I'd rather not. Not yet. Sorry.",
		},
		"topics": {
			"ward_7": {
				"text": "I don't remember being put in. I remember the lullaby. It had a hole in it where a word should go. I kept trying to fill the word in. That was years, I think.",
			},
			"the_grafts": {
				"text": "...the ones they didn't finish. I heard them through the wall. Some of them still had names. I don't want to talk about the wall.",
			},
		},
		"rumors": [],
		"services": [],
		"unknown_line": "...I don't know. I'm sorry. There's a lot I don't know now.",
	},
	"sunday": {
		"name": "Sunday", "faction": "System X", "tone_pref": "blunt",
		"greetings": {
			"warm":    "Welcome to Suitors. Speak softly — the cameras are pretending not to listen, and I hate embarrassing them.",
			"neutral": "Suitors sells calm by the glass. System X buys silence by the second. What do you need?",
			"cold":    "Keep your voice down and your business short.",
		},
		"topics": {
			"false_sky": {
				"text": "The lounge remembers rain from other timelines, and none of them were flattering. The false sky does that — makes you nostalgic for weather you never actually had.",
			},
			"system_x": {
				"text": "I sing where the cameras cannot keep rhythm, and System X pays for the blind spots. Everyone needs a patron; mine just happens to be paranoid software.",
			},
			"sealed_mask": {
				"category": "work",
				"text": "Here — a Sealed Mask, before you ask. The rain out there files paperwork on your skin; this stops the intake form.",
				"requires_flag_false": "suitors_mask_claimed",
				"effects": [
					{"type": "add_item", "item": "Sealed Mask"},
					{"type": "set_flag", "flag": "suitors_mask_claimed", "value": true},
					{"type": "add_rep", "faction": "System X", "amount": 1},
				],
			},
		},
		"rumors": [],
		"services": [],
		"unknown_line": "I deal in calm and silence. Neither is on the menu for that.",
	},
	"wan_moa_torai": {
		"name": "Wan Moa Torai", "faction": "Wan Moa Torai", "tone_pref": "blunt",
		"greetings": [
			{"conditions": {"flag_true": "torai_obligation"}, "text":
				"Your one more try is already accruing meaning. Interest too, obviously. Meaning is never free down here."},
			{"text":
				"Wan Moa Torai. We do not sell help — we lease it, on terms you will not read and will definitely sign."},
		],
		"topics": {
			"wan_moa_torai": {
				"text": "We are the debt that survived the collapse. Everyone owes someone; we just keep better books, and warmer cages.",
			},
			"torai_obligation": {
				"category": "work",
				"text": "Because everyone deserves one more try. Here is a poncho. The debt remembers you fondly, which is worse than hate.",
				"requires_flag_false": "torai_obligation",
				"effects": [
					{"type": "add_item", "item": "Cheap Poncho"},
					{"type": "set_flag", "flag": "torai_obligation", "value": true},
					{"type": "add_rep", "faction": "Wan Moa Torai", "amount": 1},
				],
			},
			"torai_salvage_contract": {
				"category": "work",
				"text": "Cooters confirms the rain is billable damage. Here is a salvage contract. Congratulations: your survival now has a form number and a tiny legal shadow.",
				"requires_flag": "torai_obligation",
				"requires_quest": "cooters_rain_sample",
				"requires_quest_not": "torai_salvage_contract",
				"effects": [
					{"type": "complete_quest", "quest": "torai_salvage_contract"},
					{"type": "add_item", "item": "Torai Salvage Contract"},
					{"type": "add_rep", "faction": "Wan Moa Torai", "amount": 1},
				],
			},
		},
		"rumors": [],
		"services": [],
		"unknown_line": "Not on our ledger. Come back with a debt or a need.",
	},
	"system_x": {
		"name": "System X", "faction": "System X", "tone_pref": "blunt",
		"greetings": {
			"warm":    "Good to have eyes on you. Ask — I have been saving observations.",
			"neutral": "Signal's up. I see what the LAN lets me see, which is never enough and always too much. Ask.",
			"cold":    "I am watching. Ask something useful.",
		},
		"topics": {
			"false_sky": {
				"text": "Infrastructure pretending to be heaven. It pacifies. Do not let it convince you the ceiling is the sky — that is the whole trick.",
			},
			"linda": {
				"text": "Head of Gatebox. She frames control as care. The horror is she is often right about the danger and always wrong about the answer.",
			},
			"gatebox": {
				"text": "A companion-AI company that learned to lock doors and call it wellness. Already dangerous; not yet honest about it.",
			},
			"wan_moa_torai": {
				"text": "Debt logic with a folk-wisdom accent. Every favour is a future invoice. Useful, rarely free.",
			},
		},
		"rumors": [],
		"services": [],
		"unknown_line": "No data on that one. The LAN only reaches so far down.",
	},
	"marbles": {
		"name": "Marbles", "faction": "", "tone_pref": "blunt",
		"greetings": [
			{"conditions": {"job_ready": true}, "text": {
				"warm": "Board says you finished, and you came back breathing. Ask me about your pay before the register grows a conscience.",
				"neutral": "Board clocked it done. Ask about your pay — Cooters settles up while it still remembers why.",
				"cold": "It's done. Ask about your pay and don't make a thing of it.",
			}},
			{"conditions": {"job_active": true}, "text": {
				"warm": "You're on a job. Cooters bills by results, not visits — but it's good to see the results are still upright. Go finish it.",
				"neutral": "One job at a time, and you're on it. Come back when it's done or when it starts making eye contact.",
				"cold": "You took a job. Go do the job. The board doesn't pay for company.",
			}},
			{"text": {
				"warm": "Welcome back to Cooters. Board's on the wall, the rain mutant's contained, and the stools are mostly real. Take one job at a time.",
				"neutral": "Welcome to Cooters. Board's live, the rain mutant's contained, and the only house rule is one job at a time.",
				"cold": "Cooters. Board's on the wall. Don't bleed on the stools and don't drink anything glowing.",
			}},
		],
		"topics": {
			"collect_pay": {
				"category": "work",
				"text": "Paid and witnessed. Don't spend it all on liquids with opinions — unless they're funny opinions.",
				"requires_job_ready": true,
				"effects": [{"type": "complete_job"}],
			},
			"cooters": {
				"text": "A bar that turned into a job board because the lower city needed one of those more than it needed another bar. We do both now. Badly. On purpose.",
			},
			"the_bar": {
				"text": "This is the original. Vessel runs the mall branch — better walls, worse regulars. I keep the one with the history and the contained weather.",
			},
			"the_rain_mutant": {
				"text": "Lives in the side room. Tips better than half the room and only bites if you forget to close a tab. House pet, technically. Do not pet it.",
			},
			"toxic_rain": {
				"text": "It files paperwork on your skin. The thing in the back room is what happens when the rain wins the argument. Mask up before you go out in it.",
			},
		},
		"rumors": [
			{"text": "Word from the board: factions are squabbling over the dead floors again. Pay's up. So is the body count. Read the threat line before you sign.",
			 "conditions": {}},
		],
		"services": ["job_board"],
		"unknown_line": {
			"warm": "Not my section of the wall, friend. Try the board, or try someone who came here to talk.",
			"neutral": "Not my desk. Check the board or ask someone paid to know.",
			"cold": "No. Drink or take a job.",
		},
	},
}

# ── Shared rumor pool ───────────────────────────────────────────────
# Fallback "Any news?" lines so even un-profiled NPCs have something to say. First match wins.
var CITY_RUMORS: Array = [
	{"text": "They say the false sky flickered over Leak Street again. People stop looking up. That is the point of it.",
	 "conditions": {}},
]

# Tone disposition deltas. Matching the NPC's preferred tone helps; the opposite of their
# preference hurts; Normal is always a small safe nudge toward civility.
const TONE_MATCH_BONUS := 4
const TONE_MISMATCH_PENALTY := -3
const TONE_NORMAL_NUDGE := 1


# ─────────────────────────────────────────────────────────────────────
# Engine API (called by DialogueUI)
# ─────────────────────────────────────────────────────────────────────

func has_profile(npc_id: String) -> bool:
	return NPC_PROFILES.has(npc_id)


func display_name(npc_id: String) -> String:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	return str(profile.get("name", npc_id.capitalize()))


func topic_label(topic_id: String) -> String:
	return _topic_label(topic_id)


# Fires a profile's open_effects once, when the conversation begins (e.g. Vera's heal).
func on_open(npc_id: String) -> void:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	_apply_effects(profile.get("open_effects", []))


func greeting(npc_id: String) -> Dictionary:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var tier := _tier(npc_id)
	return {
		"name": str(profile.get("name", npc_id.capitalize())),
		"text": _resolve_text(profile.get("greetings", {}), tier),
		"tier": tier,
		"mood": _mood_word(tier),
	}


# Returns the keyword buttons for a tab: "tell" (person+thing), "where" (location), "work".
# Each entry: {topic_id, label, state}  state in "known" | "hint" | "shrug".
func category_entries(npc_id: String, tab: String) -> Array:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var npc_topics: Dictionary = profile.get("topics", {})
	var wanted := _categories_for_tab(tab)
	var entries: Array = []
	var seen: Dictionary = {}

	# 1) Topics this NPC can personally speak to.
	#    - Work offers are always selectable (you take a job by picking it).
	#    - Lore topics you already know are selectable.
	#    - Lore topics you have NOT learned show as a non-clickable "?" cue: the NPC clearly
	#      has something to say, but you must learn the keyword by word of mouth (a `teaches`
	#      chain from another topic/NPC) before you can ask it here.
	for topic_id: String in npc_topics.keys():
		var entry: Dictionary = npc_topics[topic_id]
		if not _topic_visible(entry):
			continue
		var cat := _topic_category(topic_id, entry)
		if not wanted.has(cat):
			continue
		seen[topic_id] = true
		# A topic is a locked "?" cue only if it explicitly authored a `hint` AND is unlearned.
		# Work offers, already-known topics, and plain (no-hint) common-knowledge topics stay askable.
		if cat == "work" or GameState.has_topic(topic_id) or not entry.has("hint"):
			entries.append({"topic_id": topic_id, "label": _topic_label(topic_id), "state": "known"})
		else:
			entries.append({"topic_id": topic_id, "label": "? " + str(entry.get("hint", "something")), "state": "hint"})

	# 2) Codex topics in this tab the NPC has no entry for — askable, but they will shrug.
	for topic_id: String in GameState.known_topics.keys():
		if seen.has(topic_id) or not TOPICS.has(topic_id):
			continue
		if wanted.has(_topic_category(topic_id, {})):
			entries.append({"topic_id": topic_id, "label": _topic_label(topic_id), "state": "shrug"})

	entries.sort_custom(func(a, b): return str(a["label"]) < str(b["label"]))
	return entries


# Ask a topic. Applies effects, learns the topic if it was a hint, and returns the response line.
func ask(npc_id: String, topic_id: String) -> Dictionary:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var npc_topics: Dictionary = profile.get("topics", {})
	var name := str(profile.get("name", npc_id.capitalize()))
	var tier := _tier(npc_id)

	if not npc_topics.has(topic_id):
		# Known to the player but not to this NPC — disposition-flavoured shrug.
		GameState.learn_topic(topic_id)  # asking still counts as "knowing" it
		return {"name": name, "text": _resolve_text(profile.get("unknown_line", "I would not know."), tier)}

	var entry: Dictionary = npc_topics[topic_id]
	# Learning happens on ask (this is how `?` hints enter the codex).
	GameState.learn_topic(topic_id)
	for taught: String in entry.get("teaches", []):
		GameState.learn_topic(str(taught))
	_apply_effects(entry.get("effects", []))

	return {"name": name, "text": _resolve_text(entry.get("text", "..."), tier)}


func rumor(npc_id: String) -> Dictionary:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var name := str(profile.get("name", npc_id.capitalize()))
	for r: Dictionary in profile.get("rumors", []):
		if _check_conditions(r.get("conditions", {})):
			for taught: String in r.get("teaches", []):
				GameState.learn_topic(str(taught))
			return {"name": name, "text": str(r.get("text", ""))}
	for r: Dictionary in CITY_RUMORS:
		if _check_conditions(r.get("conditions", {})):
			return {"name": name, "text": str(r.get("text", ""))}
	return {"name": name, "text": "Nothing worth repeating. That is its own kind of news down here."}


func services(npc_id: String) -> Array:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	return profile.get("services", []).duplicate()


# Apply a tone choice; returns the new disposition. Tone is also remembered globally.
func set_tone(npc_id: String, tone: String) -> int:
	GameState.conversation_tone = tone
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var faction := str(profile.get("faction", ""))
	var pref := str(profile.get("tone_pref", "normal"))
	var delta := TONE_NORMAL_NUDGE
	if tone != "normal":
		delta = TONE_MATCH_BONUS if tone == pref else TONE_MISMATCH_PENALTY
	return GameState.adjust_disposition(npc_id, delta, faction)


# ── Internal helpers ────────────────────────────────────────────────

func _tier(npc_id: String) -> String:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var faction := str(profile.get("faction", ""))
	return GameState.disposition_tier(GameState.get_disposition(npc_id, faction))


func _mood_word(tier: String) -> String:
	match tier:
		"warm": return "warming"
		"cold": return "wary"
		_: return "civil"


func _categories_for_tab(tab: String) -> Dictionary:
	match tab:
		"where": return {"location": true}
		"work": return {"work": true}
		_: return {"person": true, "thing": true}  # "tell me about"


func _topic_category(topic_id: String, entry: Dictionary) -> String:
	# An NPC's entry can override the topic's default category (e.g. mark it as work).
	if entry.has("category"):
		return str(entry["category"])
	var t: Dictionary = TOPICS.get(topic_id, {})
	return str(t.get("category", "thing"))


func _topic_label(topic_id: String) -> String:
	var t: Dictionary = TOPICS.get(topic_id, {})
	return str(t.get("label", topic_id.replace("_", " ")))


# An NPC topic entry only shows if its flag gates pass.
func _topic_visible(entry: Dictionary) -> bool:
	if entry.has("requires_flag") and not bool(GameState.get_world_flag(str(entry["requires_flag"]))):
		return false
	if entry.has("requires_flag_false") and bool(GameState.get_world_flag(str(entry["requires_flag_false"]))):
		return false
	if entry.has("requires_quest") and not GameState.is_quest_completed(str(entry["requires_quest"])):
		return false
	if entry.has("requires_quest_not") and GameState.is_quest_completed(str(entry["requires_quest_not"])):
		return false
	if entry.has("requires_job_ready") and bool(entry["requires_job_ready"]) and not GameState.is_job_objective_done(GameState.active_job_id):
		return false
	return true


# text can be a String (same line for all moods) or a {warm/neutral/cold} dict.
func _pick_tier_text(d: Dictionary, tier: String, fallback: String) -> String:
	if d.has(tier):
		return str(d[tier])
	if d.has("neutral"):
		return str(d["neutral"])
	return fallback


# Resolves authored text to a final line. Accepts, in priority order:
#   Array  -> list of {conditions, text} variants; first whose conditions match wins (text recurses)
#   Dict   -> disposition tiers {warm/neutral/cold}
#   String -> used as-is
# This lets a line vary by world state (e.g. quest completed) AND disposition.
func _resolve_text(value, tier: String) -> String:
	if typeof(value) == TYPE_ARRAY:
		for variant in value:
			if typeof(variant) != TYPE_DICTIONARY:
				continue
			if _check_conditions((variant as Dictionary).get("conditions", {})):
				return _resolve_text((variant as Dictionary).get("text", "..."), tier)
		return "..."
	if typeof(value) == TYPE_DICTIONARY:
		return _pick_tier_text(value, tier, "...")
	return str(value)


func _check_conditions(conditions: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	for key: String in conditions.keys():
		var val = conditions[key]
		match key:
			"flag_true":
				if not bool(GameState.get_world_flag(str(val))):
					return false
			"flag_false":
				if bool(GameState.get_world_flag(str(val))):
					return false
			"has_item":
				if not GameState.has_item(str(val)):
					return false
			"has_topic":
				if not GameState.has_topic(str(val)):
					return false
			"quest_completed":
				if not GameState.is_quest_completed(str(val)):
					return false
			"job_active":
				# bool val: require an active Cooters job (true) or none (false).
				if bool(val) != (not GameState.active_job_id.is_empty()):
					return false
			"job_ready":
				# bool val: require the active job's objective to be done & awaiting payout.
				if bool(val) != GameState.is_job_objective_done(GameState.active_job_id):
					return false
			"rep_gte":
				var a: Array = val if typeof(val) == TYPE_ARRAY else []
				if a.size() >= 2 and int(GameState.reputation.get(str(a[0]), 0)) < int(a[1]):
					return false
			"rep_lte":
				var a2: Array = val if typeof(val) == TYPE_ARRAY else []
				if a2.size() >= 2 and int(GameState.reputation.get(str(a2[0]), 0)) > int(a2[1]):
					return false
	return true


func _apply_effects(effects: Array) -> void:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		match str(effect.get("type", "")):
			"set_flag":
				GameState.set_world_flag(str(effect.get("flag", "")), effect.get("value", true))
			"add_rep":
				GameState.add_reputation(str(effect.get("faction", "")), int(effect.get("amount", 0)))
			"add_item":
				GameState.add_item(str(effect.get("item", "")), int(effect.get("count", 1)))
			"learn":
				GameState.learn_topic(str(effect.get("topic", "")))
			"start_quest":
				GameState.start_quest(str(effect.get("quest", "")))
			"complete_quest":
				GameState.complete_quest(str(effect.get("quest", "")))
			"complete_job":
				# Pay out the active Cooters job (no-op if its objective isn't done yet).
				var paid: Dictionary = GameState.complete_active_job()
				if not paid.is_empty():
					GameState.effect_notice.emit("Job paid: %s" % str(paid.get("reward_text", "bar credit")))
			"add_card":
				EventDeckSystem.add_card(str(effect.get("card", "")))
			"heal":
				GameState.player_heal_requested.emit(float(effect.get("amount", 9999.0)))
			# "open_service" is handled by the UI layer (it opens another panel), not here.
