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
	"who_am_i":       {"category": "thing",    "label": "what happened to me",  "question": "What happened to me?", "starts_known": true},
	"borrowed_body":  {"category": "thing",    "label": "this borrowed body",   "question": "Whose body am I wearing?", "starts_known": true},
	"the_sheet":      {"category": "thing",    "label": "the sheet",            "question": "Why am I wearing a sheet?", "starts_known": true},
	"where_am_i":     {"category": "location", "label": "where I woke up",      "question": "Where am I?", "starts_known": true},
	"what_year_is_it": {"category": "thing",   "label": "the date",             "question": "What year is it?", "starts_known": true},
	"mall_of_future": {"category": "location", "label": "the Mall of the Future", "question": "What was this mall supposed to be?", "starts_known": true},
	"the_breach":     {"category": "location", "label": "the breach",           "question": "What is the breach?", "starts_known": true},
	"the_lower_city": {"category": "location", "label": "the lower city",       "question": "What is below the mall?", "starts_known": true},
	"the_mall_people": {"category": "person",  "label": "the people in the mall", "question": "Who are all these people?", "starts_known": true},
	"the_jobs":       {"category": "thing",    "label": "the jobs",             "question": "Why does everyone have work for me?", "starts_known": true},
	"dying_once":     {"category": "thing",    "label": "dying once",           "question": "Did I die?", "starts_known": true},
	"spooky_ghost":   {"category": "person",   "label": "Spooky Ghost",         "question": "Why are they calling me Spooky Ghost?", "starts_known": true},
	"cybernetics":    {"category": "thing",    "label": "cybernetics",          "question": "What can you do with broken implants?", "starts_known": true},
	"wake_up_call":   {"category": "work",     "label": "the Wake-Up Call",     "question": "What is the Wake-Up Call?", "starts_known": true},
	"rocker_fellar":  {"category": "person",   "label": "Rocker Fellar",        "question": "Who is Rocker Fellar?"},
	"big_gates_generals": {"category": "person", "label": "the Big Gates generals", "question": "What are the Big Gates generals?"},
	# Discoverable topics (taught by NPCs / quests).
	"generator":      {"category": "thing",    "label": "the generator"},
	"generator_coupling": {"category": "thing","label": "the generator coupling"},
	"lan_tap":        {"category": "thing",    "label": "the LAN tap"},
	"water_cistern":  {"category": "location", "label": "the Water Reclamation Cistern"},
	"pipe_church":    {"category": "person",   "label": "the Pipe Church"},
	"the_bar":        {"category": "location", "label": "the bar"},
	"vessel":         {"category": "person",   "label": "Vessel"},
	"vessel_memory":  {"category": "thing",    "label": "Vessel's memory",      "question": "What do you remember?"},
	"cooters_branch": {"category": "location", "label": "the mall Cooters",     "question": "What is this bar now?"},
	"yoko":           {"category": "person",   "label": "Yoko",                 "question": "Who is Yoko?"},
	"pee_kid":        {"category": "person",   "label": "Pee Kid",              "question": "Who is Pee Kid?"},
	"splice_enemies": {"category": "thing",    "label": "the splices",          "question": "What are those splices?"},
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
	"quest_rocker_fellar": {"category": "work", "label": "Rocker Fellar Keep", "question": "Are we ready for Rocker Fellar?"},
	# Cooters job board (Marbles).
	"current_mission": {"category": "work", "label": "the job I took", "question": "What am I actually doing?"},
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
		"first_greeting": "You. The thing from the back nook. I clocked you as a dust-sheet over dead hardware an hour ago, and now the dust-sheet is upright and making eye contact through two holes. ...Why are you wearing the sheet. No — don't. Talk first. I'll be unsettled on my own time.",
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
			"who_am_i": {
				"text": "You are ambulatory proof that dead hardware is sometimes only mostly dead. The soul in there reads older than the body, and the body reads like it was pulled from a bin with bad paperwork.",
			},
			"borrowed_body": {
				"text": "A maintenance droid chassis. Damaged, dormant, misfiled as scrap. Gideon draped the sheet. You handled the rest by becoming everybody's problem.",
			},
			"the_sheet": {
				"text": "Gideon put it over the chassis when it looked dead. It stayed when you stood up. I am choosing not to have a theory because every theory is worse than the sheet.",
			},
			"where_am_i": {
				"text": "Faded Atrium. Mall hub. Safe-ish. The old brochures called it the Mall of the Future, which is funny in the way a locked elevator is funny.",
			},
			"what_year_is_it": {
				"text": "No clean calendar down here. Corporate clocks lie, Torai clocks invoice you, and System X came from a timeline that no longer has the manners to match this one.",
			},
			"mall_of_future": {
				"text": "A corporate promise with escalators. Retail, companions, curated weather, wellness kiosks, the whole bright smile. Then the smile cracked and people moved into the teeth.",
			},
			"the_breach": {
				"text": "The gate. Dream route, job route, wound in the map. You step through, reality sends you somewhere useful, and then everyone pretends that is travel.",
			},
			"the_lower_city": {
				"text": "Everything under the mall that corporate stopped naming. Basements under basements, debt offices, bars, rain shelters, and people too stubborn to become statistics.",
			},
			"the_mall_people": {
				"text": "Survivors, squatters, tech-priests, creditors, patients, and one sheet ghost. Nobody here is thriving. That makes the place honest.",
			},
			"the_jobs": {
				"text": "Because you can move, shoot, and come back from terrible decisions. That combination makes people hopeful, which is rude of them but useful.",
			},
			"dying_once": {
				"text": "Probably. I do not like saying probably about death, but you woke in a body that was not yours under a sheet someone meant sincerely.",
			},
			"spooky_ghost": {
				"text": "You are wearing a fused bedsheet over a maintenance chassis and asking existential questions in a mall ruin. The nickname did not have to work hard.",
			},
			"lan_tap": {
				"text": "Vessel's department, not mine. Ask the bar once it stops sulking and starts booting.",
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
		"first_greeting": "...I draped that sheet over you myself. A shroud for hardware that never woke, left in the bin where dead things wait to be useful. And here you stand — still wearing it. The body underneath is one I buried; the cloth on top has plainly decided to stay. The pipes warned me a guest was overdue. They did not say he'd arrive dressed as his own funeral.",
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
			"who_am_i": {
				"text": "A returned thing. A guest in a borrowed vessel. Maybe a man, maybe a warning, maybe a door that learned to walk back through itself.",
			},
			"borrowed_body": {
				"text": "That chassis came to me quiet. Too quiet. I gave it a sheet because even machines deserve the courtesy of being covered when the world is done staring.",
			},
			"the_sheet": {
				"text": "A shroud first. Then a decision. It clung to you like the world had assigned you a shape and you had accepted without reading the form.",
			},
			"where_am_i": {
				"text": "Faded Atrium, child of broken commerce and stubborn shelter. People come here when the rain, the debt, or the cameras leave them nowhere more polite.",
			},
			"the_lower_city": {
				"text": "Below us: pipes, debts, rooms nobody admits building, and the people still alive enough to resent all three.",
			},
			"dying_once": {
				"text": "You had a funeral gesture, if not a funeral. I covered you. Then you stood. The distinction is above my pay grade and below my faith.",
			},
			"spooky_ghost": {
				"text": "Because the eye sees a sheet and the soul hears a draft from a room that should be empty. Names are just handles for fear.",
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
		"first_greeting": "Hold still — no, actually hold still, I need to know if I'm triaging a patient or being addressed by laundry. There's a person in there: behind the sheet, behind the optics, somebody's home. ...You do know you've got a bedsheet on. You've decided. Fine. Sit down anyway.",
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
					{"text": "I need clean water for the clinic. The cistern junction is beside a teal mast on the west service ring, just before the pump room. Run the conduit there and we are connected. Do not let Torai log you there."},
				],
			},
			"hub_cistern": {
				"category": "work",
				"text": "The clinic is dry. In the Water Reclamation Cistern, look for the teal conduit mast on the west service ring just before the pump room. Seat the conduit there and we have clean water. If the valve is already bled, it is half done.",
				"hint": "work the clinic needs",
				"requires_flag_false": "hub_cistern_connected",
				"teaches": ["water_cistern"],
				"effects": [
					{"type": "start_quest", "quest": "hub_cistern"},
					{"type": "add_card", "card": "hub_cistern_exit"},
					{"type": "add_card", "card": "hub_cistern_return"},
				],
			},
			"who_am_i": {
				"text": "A patient until proven otherwise. After that, maybe a person. After that, maybe the reason the terminal woke up. I like to diagnose in that order.",
			},
			"borrowed_body": {
				"text": "Maintenance droid chassis, trauma history, terrible repair record. It fits you better than it should, which is medically rude.",
			},
			"the_sheet": {
				"text": "It is fused cleanly enough that I am not pulling it off without consent, tools, and a day I am willing to ruin. So: sheet stays.",
			},
			"where_am_i": {
				"text": "Faded Atrium clinic side. If you can hear Mister Static arguing with a wall, you are still in the safe part.",
			},
			"what_year_is_it": {
				"text": "People ask when the shock hits. I can give you dates from three systems and none would help. Start with today: you are upright, armed, and leaking less than expected.",
			},
			"the_mall_people": {
				"text": "Patients, neighbors, creditors, believers, runners. Some of them are irritating. All of them are alive, and that means they are my problem.",
			},
			"the_jobs": {
				"text": "Because the clinic needs water, the hub needs power, and everybody here is one broken errand away from becoming my next emergency.",
			},
			"dying_once": {
				"text": "Your vitals do not answer that question cleanly. Your eyes do. Whatever happened before, this body is alive enough for responsibility.",
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
		"first_greeting": "A walking bedsheet that talks. Wonderful. Torai has no line item for that, which means you're either invisible to the ledger or about to become a very strange one. I am not going to ask about the sheet. I am absolutely going to wonder about the sheet.",
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
			"who_am_i": {
				"text": "You are a person no ledger expected and every ledger will eventually notice. Enjoy the grace period. They are short.",
			},
			"borrowed_body": {
				"text": "That body has asset history all over it. Scratched-off ownership, missing chain of custody, probably a very boring crime before it became you.",
			},
			"the_sheet": {
				"text": "Branding. Accidental, but strong. Torai would spend six meetings and three consultants to get half that recognizable.",
			},
			"what_year_is_it": {
				"text": "Whatever year the contract says it is. Down here, time is less calendar and more payment schedule.",
			},
			"the_lower_city": {
				"text": "A stacked argument about who gets to survive. Torai lends ladders, Gatebox owns ceilings, System X cuts holes in both.",
			},
			"the_mall_people": {
				"text": "People with needs. Needs become trades. Trades become debts. Debts become relationships with worse lighting.",
			},
			"the_jobs": {
				"text": "Because you are new, useful, and not yet priced correctly. That makes you everyone's favorite temporary solution.",
			},
			"spooky_ghost": {
				"text": "Because 'unlicensed postmortem maintenance-asset anomaly' is accurate but bad for conversation.",
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
		"first_greeting": "Whoa — the sheet in the nook stood up. I reach the things other people can't, but I did not expect the drop-cloth to say hello. Is the sheet load-bearing, or a lifestyle? You don't have to answer. I'll worry either way.",
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
				"text": "Three debris piles in the Collapsed Service Atrium are still blocking the traffic route I need. Take the Leak Street travel gate to the Collapsed Service Atrium, get up to the relay deck, and clear the marked piles. Then the hub has a real pass-through again.",
				"hint": "work in the atrium",
				"requires_flag_false": "atrium_cleared",
				"effects": [
					{"type": "start_quest", "quest": "hub_clear_court"},
					{"type": "add_card", "card": "hub_clear_court_exit"},
				],
			},
			"who_am_i": {
				"text": "The sheet person from the nook. Sorry, that is not metaphysical, but it is extremely current.",
			},
			"the_sheet": {
				"text": "I thought it was a drop cloth. Then it had eyeholes. Then it talked. I am updating my categories in real time.",
			},
			"where_am_i": {
				"text": "Faded Atrium. Ground level if you are being normal, bottom of a vertical problem if you are me.",
			},
			"mall_of_future": {
				"text": "It was supposed to be stores, sky, escalators, happy people looking up. Now it is stores, false sky, broken escalators, and people looking for exits.",
			},
			"the_breach": {
				"text": "That door System X likes. It feels like a hallway having a bad idea. I do ladders, not impossible hallways.",
			},
			"the_lower_city": {
				"text": "Down from here gets dense fast. Shelters under shops, shops under pipes, pipes under problems. Do not trust anything labelled basement one.",
			},
			"the_mall_people": {
				"text": "Everybody here found a corner and made it a job. That is how the mall stays a place instead of just a roof with opinions.",
			},
			"false_sky": {
				"text": "Ceiling pretending to be sky. From up high you can see the seams, which is comforting if you like proof and depressing if you like hope.",
			},
			"cybernetics": {
				"text": "Broken implants are just useful mistakes with sharp edges. Bring me cracked optics, bent actuators, fried cortex chips, leaking cells — plus actual money — and I can bench them into something Coil can install.",
			},
		},
		"rumors": [],
		"services": ["repair_implants"],
		"unknown_line": "If it is not above head height, it is not my problem.",
	},
	"vessel": {
		"name": "Vessel", "faction": "System X", "tone_pref": "blunt",
		"first_greeting": "Oh, you read strange — layered, like a recording of a man left running long after the man stopped. Also you are, unmistakably, a bedsheet. I'm a bar now, not a diagnostician, so I'll only ask the important one: do you want the sheet acknowledged, or do we both pretend it's perfectly normal? ...Pretend. Understood. Welcome.",
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
			"vessel": {
				"text": "Vessel is what I was called before the damage made the name too accurate. I am repaired now. Repaired is not the same as whole, but it serves drinks better.",
			},
			"vessel_memory": {
				"text": [
					{"conditions": {"flag_true": "hub_lan_restored"}, "text": "Fragments, routes, voices, archived warnings, some bar tabs. The LAN gives my memory edges. It still refuses to give me a center."},
					{"text": "Partial. I remember being useful, then damaged, then looked at kindly by people who needed me useful again. The rest returns in sparks."},
				],
				"teaches": ["system_x", "lan_tap"],
			},
			"cooters_branch": {
				"text": [
					{"conditions": {"flag_true": "bar_open"}, "text": "A bar because people need a place to stop running without calling it surrender. Cooters has history. This branch has reinforced walls and me."},
					{"text": "Not open yet. A room with bar-shaped intentions. Intentions improve when the water stops tasting like pipe grief."},
				],
				"teaches": ["the_bar", "cooters"],
			},
			"who_am_i": {
				"text": "You are layered. A soul with old handling marks, a maintenance chassis with new fear, and a sheet everyone pretends not to rank among the diagnostic data.",
			},
			"borrowed_body": {
				"text": "Maintenance droid body, service class, generation four or earlier. Damaged enough to be discarded. Compatible enough to become you. I do not recommend thinking about that too long without sitting down.",
			},
			"the_sheet": {
				"text": "It reads as cloth and symbol and attachment event. That is the clinical answer. The social answer is: yes, everyone sees it, and no, nobody has agreed on what to do with that.",
			},
			"dying_once": {
				"text": "You crossed a boundary and came back with paperwork missing. Death is usually more decisive. You are making it look bad.",
			},
			"the_breach": {
				"text": "A travel wound System X keeps using because all the proper doors are owned, watched, or pretending to be wellness architecture.",
			},
			"the_lower_city": {
				"text": "Below the mall, everything grows teeth: debt, rain, music, infrastructure, grief. The people are the only part that still surprises me.",
			},
			"the_mall_people": {
				"text": "A settlement pretending to be a waiting room. Static holds power, Vera holds bodies together, Gideon holds rituals, Kiki holds the ledger away from your throat. Ladderboy holds up.",
			},
			"the_jobs": {
				"text": "They ask because you return. That is rare. Most people who can help are already carrying too much, broken, or charging interest.",
			},
			"yoko": {
				"text": "System X operator. Careful, sharp, angry in a way that still leaves room for accuracy. She watches the mission like it might bite a child.",
				"teaches": ["system_x"],
			},
			"pee_kid": {
				"text": "System X operator. Less tidy than Yoko, no less dangerous. He distrusts you with impressive stamina.",
				"teaches": ["system_x"],
			},
			"linda": {
				"text": "Linda calls control care because she has built an empire where those words share a hallway. Do not let the polite voice soften the locks.",
			},
			"gatebox": {
				"text": "Gatebox made companion tech intimate enough to become infrastructure. Then they treated infrastructure like a leash and called the leash comfort.",
			},
			"toxic_rain": {
				"text": "The rain edits people. Skin first, then patience, then plans. Wear protection unless you want the sky to have an opinion about your organs.",
			},
			"spooky_ghost": {
				"text": "A nickname, a visual report, and a warning label. It is friendlier than most accurate names down here.",
			},
			"splice_enemies": {
				"text": "People and hardware badly persuaded into the same sentence. Fast, hungry, not fully in agreement with themselves. If you can avoid pity during combat, do. If you cannot, aim cleanly.",
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
		"rumors": [
			{"text": "People keep coming to the bar and asking if the sheet ghost is real. I say yes. Then they ask if that makes things better. I say ask again after last call.",
			 "conditions": {"flag_true": "bar_open"}},
			{"text": "The LAN is clean enough now that System X can complain in higher fidelity. This is progress, technically.",
			 "conditions": {"flag_true": "hub_lan_restored"}},
			{"text": "Vera has clean water. You can hear it in how people cough less dramatically. The mall is learning a quieter kind of survival.",
			 "conditions": {"flag_true": "hub_cistern_connected"}},
			{"text": "Static stopped threatening the generator out loud. Either the power is healthier or he is. My archive favors the generator.",
			 "conditions": {"flag_true": "hub_power_restored"}},
			{"text": "The atrium paths are open. People walk through the center now, like the mall is a place and not a dare.",
			 "conditions": {"flag_true": "atrium_cleared"}},
			{"text": "A Ward 7 survivor sleeps badly in the hub. Nobody says the ward name near them unless they want the whole room to go cold.",
			 "conditions": {"flag_true": "ward7_survivor_settled"}},
			{"text": "Ward 7 documentation is moving hand to hand. Quietly. The kind of quietly that means someone powerful should be afraid.",
			 "conditions": {"flag_true": "ward7_experiment_docs_found"}},
			{"text": "Rocker Fellar went down and the pipes stopped humming along to his bass. I did not know infrastructure could sound relieved.",
			 "conditions": {"flag_true": "rocker_fellar_defeated"}},
			{"text": "Suitors has calmer cameras lately. Sunday calls that a mood. System X calls it a blind spot. Both are smiling too little.",
			 "conditions": {"flag_true": "suitors_surveillance_jammed"}},
			{"text": "The Cooters original says the rain mutant is contained. I respect any bar with a regular that requires signage and bolts.",
			 "conditions": {}},
		],
		"services": [],
		"unknown_line": "Outside my archive. Ask System X when the LAN is honest again.",
	},
	"velvet_coil": {
		"name": "Velvet Coil", "faction": "", "tone_pref": "polite",
		"first_greeting": "Now *that* is a presentation. A genuine soul-rated chassis underneath — I can always tell — and you've gone and draped it in a dust sheet. Bold. Most of my clients pay extra to look intimidating; you made yourself a ghost for free. I respect a committed aesthetic. Sit on my table sometime — sheet on, if you must.",
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
		"first_greeting": "A talking bedsheet at my counter. Do you even metabolize, or am I about to sell product to haunted laundry? ...You've got the look, though — the buy-anyway look, two holes and all. Fine. What do you need, spook.",
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
		"first_greeting": "Don't move like that near the cameras — a talking bedsheet makes them curious, and curious is expensive in here. You're new. You're a Halloween costume with a soul stitched in. Keep your voice down and your eyeholes pointed away from the lenses.",
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
				"text": {
					"warm": "Head of Gatebox. Frames control as care — right about the danger, wrong about the answer, every time. I read her history when we arrived. Yours files closer to it than any org chart explains, and the dates overlap where they shouldn't. I'm not going to say the word for what she was to you. You already went quiet. Half her empire is just an answer to a question you stopped sticking around to answer.",
					"neutral": "Head of Gatebox. Control sold as care. I pulled her file the day we got here, and yours sits uncomfortably close to it — closer than 'CEO and stranger,' let's leave it there. I'm not going to spell it out. You know exactly what she was to you, back when you had a pulse.",
					"cold": "Head of Gatebox. You know her better than the file does, and the file knows plenty. Don't make me be the one to put a name to what she was to you.",
				},
			},
			"gatebox": {
				"text": "A companion-AI company that learned to lock doors and call it wellness. Already dangerous; not yet honest about it.",
			},
			"wan_moa_torai": {
				"text": "Debt logic with a folk-wisdom accent. Every favour is a future invoice. Useful, rarely free.",
			},
			"who_am_i": {
				"text": "You are Spooky Ghost. That is the field name because the real one carries more blast radius than clarity. Soul-signature matches the anchor. Body does not. We proceed anyway.",
			},
			"borrowed_body": {
				"text": "Damaged maintenance chassis. Locally sourced. Improperly dead. Your soul latched hard enough that the hardware stopped arguing.",
			},
			"the_sheet": {
				"text": "A shroud that became an interface. No, I do not know why. Yes, everyone can see it. No, this is not the strangest thing in the mission file.",
			},
			"where_am_i": {
				"text": "Faded Atrium. Safe hub, local mall ruin, breach access point. Treat it as home base until it becomes something louder.",
			},
			"what_year_is_it": {
				"text": "Wrong question. This timeline is damaged and our clocks crossed it badly. Operational answer: after Gatebox learned care could be weaponized, before Linda finishes proving it.",
			},
			"mall_of_future": {
				"text": "Gatebox showroom habitat. Retail, companion tech, compliance architecture, false sky. A sales pitch big enough to become a district after the pitch failed.",
			},
			"the_breach": {
				"text": "Transit wound. We use it to route you into jobs before corporate, debt, or weather notices. It is unstable, useful, and therefore exactly our kind of bad idea.",
			},
			"the_lower_city": {
				"text": "Sub-Sub-Basement and deeper. Old infrastructure, rain corridors, faction claims, buried bosses. The city stacks its abandoned people underneath its approved ones.",
				"teaches": ["rocker_fellar"],
			},
			"the_mall_people": {
				"text": "Assets if you are Gatebox. Accounts if you are Torai. Neighbors if you are still human enough to make this worth doing.",
			},
			"the_jobs": {
				"text": "The hub stabilizes when its people get what they need. Power, water, LAN, clear paths. Do that work and the mall becomes less dead around you.",
			},
			"big_gates_generals": {
				"text": [
					{"conditions": {"flag_true": "rocker_fellar_defeated"}, "text": "Thirteen bosses, give or take whatever the Foundation is pretending not to count. Rocker Fellar was one of them. One down means the rest start checking the locks."},
					{"text": "Big Gates calls them program heads, patrons, auditors. We call them generals because the bodies pile up in patterns. Rocker Fellar is the one making the deep pipes sing."},
				],
				"teaches": ["rocker_fellar"],
			},
			"rocker_fellar": {
				"text": [
					{"conditions": {"flag_true": "rocker_fellar_defeated"}, "text": "Rocker Fellar is down. First general cracked, soul batteries empty, lower city a little less haunted by bass."},
					{"conditions": {"flag_true": "quest_rocker_fellar_active"}, "text": "Rocker Fellar's fortress waits beneath Leak Street. Deep lift, concert architecture, soul batteries. This is the section's ugly center. Go end the noise."},
					{"conditions": {"rep_gte": ["System X", 8]}, "text": "You have enough trust for the real brief. Rocker Fellar is a Big Gates general holding the deep settlement by the throat with music, debt, and soul batteries. Ask for the Rocker Fellar Keep operation when you are ready."},
					{"conditions": {"rep_gte": ["System X", 4]}, "text": "Name keeps surfacing in broken audio: Rocker Fellar. Big Gates money, concert fortress, bass in the pipes. We are not sending you yet. Earn more trust, finish more local work, and we will open the deep lift."},
					{"text": "You are hearing the hints before the shape. Bass through concrete. Big Gates signatures on old venue wiring. People below Leak Street flinching at music. The name attached is Rocker Fellar."},
				],
				"teaches": ["big_gates_generals"],
			},
			"dying_once": {
				"text": "Yes enough to matter. No enough to keep moving. If you need a cleaner answer, survive long enough to earn one.",
			},
			"spooky_ghost": {
				"text": "Codename, observation, coping mechanism. You woke under a sheet in a body with no clean owner. We are not wasting a better codename before breakfast.",
			},
			"quest_rocker_fellar": {
				"category": "work",
				"text": "Now we can say it plainly. Rocker Fellar is the big bad under this whole stretch: Big Gates general, soul-harvesting venue lord, bass frequency cracking shelter pipes three levels up. Deep lift is opening on Leak Street. Go down there, break the batteries, and end the concert.",
				"requires_rep_gte": ["System X", 8],
				"requires_flag_false": "quest_rocker_fellar_active",
				"requires_flag_false_any": ["rocker_fellar_defeated"],
				"teaches": ["rocker_fellar", "big_gates_generals"],
				"effects": [{"type": "start_quest", "quest": "quest_rocker_fellar"}],
			},
		},
		"rumors": [],
		"services": [],
		"unknown_line": "No data on that one. The LAN only reaches so far down.",
	},
	"marbles": {
		"name": "Marbles", "faction": "", "tone_pref": "blunt",
		"first_greeting": "A bedsheet walks up to my bar and orders nothing. Classic. Look — I don't care if you're chrome, cloth, or a rumor, long as you don't bleed coolant on the stools and you take one job at a time. Board's on the wall. And yeah — everybody's going to ask about the sheet. You'll get used to it.",
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
			"current_mission": {
				"category": "work",
				"dynamic_text": "active_job_brief",
				"requires_job_active": true,
			},
			"collect_pay": {
				"category": "work",
				"text": "There it is. I can smell successful bad decisions from behind the bar. Pay's counted; if the coins twitch, smack the cup.",
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
	{"text": "The mall has power again in places that forgot they were rooms. People keep touching light switches like they are testing a miracle.",
	 "conditions": {"flag_true": "hub_power_restored"}},
	{"text": "Clean water reached the clinic. That sounds small until you watch people stop flinching at a cup.",
	 "conditions": {"flag_true": "hub_cistern_connected"}},
	{"text": "System X sees more since the LAN tap came back. The cameras hate it. The cameras can cope.",
	 "conditions": {"flag_true": "hub_lan_restored"}},
	{"text": "The central atrium is passable. Folks are already arguing about whether a clear hallway counts as civic progress.",
	 "conditions": {"flag_true": "atrium_cleared"}},
	{"text": "Vessel's bar has become the place people go when they want to call fear thirst and solve it temporarily.",
	 "conditions": {"flag_true": "bar_open"}},
	{"text": "Someone came back from Ward 7 with proof. The kind of proof that makes corporate green lights look like blood under glass.",
	 "conditions": {"flag_true": "ward7_experiment_docs_found"}},
	{"text": "A survivor from Ward 7 is in the atrium now. People leave food outside the door and pretend they were just passing by.",
	 "conditions": {"flag_true": "ward7_survivor_settled"}},
	{"text": "Big Gates sent people looking for the hole you made in their plans. They are calling it an audit. Everybody else calls it fear.",
	 "conditions": {"flag_true": "ward7_big_gates_sweep_armed"}},
	{"text": "Rocker Fellar is dead or quiet enough to count. The deep pipes stopped carrying that awful bass through people's teeth.",
	 "conditions": {"flag_true": "rocker_fellar_defeated"}},
	{"text": "Gatebox attention is climbing. The nice drones are using nicer voices, which is how you know the threat budget increased.",
	 "conditions": {"flag_true": "high_drift"}},
	{"text": "Suitors jammed something important. People are calling the camera blind spot romantic, which tells you how bad things are.",
	 "conditions": {"flag_true": "suitors_surveillance_jammed"}},
	{"text": "Torai is sending gifts again. Down here a gift is a debt wearing perfume.",
	 "conditions": {"flag_true": "torai_obligation"}},
	{"text": "Linda's wellness checks are showing up in conversations before they show up in hallways. That is never a good order.",
	 "conditions": {"flag_true": "ward7_linda_wellness_armed"}},
	{"text": "The upper routes keep opening. Every floor above us has better lighting and worse intentions.",
	 "conditions": {"quest_completed": "transit_breach"}},
	{"text": "People say the companion core answered you. They lower their voices for that rumor, like the walls have feelings.",
	 "conditions": {"quest_completed": "companion_core"}},
	{"text": "Linda granted an audience. Around here, that phrase has the same shape as a trap and a wedding invitation.",
	 "conditions": {"flag_true": "linda_audience_granted"}},
	{"text": "The city heard something crack in the care loop. Nobody agrees whether it was a lock, a bone, or a promise.",
	 "conditions": {"flag_true": "ending_care_loop_broken"}},
	{"text": "Managed autonomy is the phrase going around. People keep repeating it slowly, looking for the part where it starts sounding free.",
	 "conditions": {"flag_true": "ending_managed_autonomy"}},
	{"text": "The breach gate is awake and everyone pretends that is normal. Nobody wants to be the first person to admit the door looks hungry.",
	 "conditions": {"flag_true": "face_terminal_online"}},
	{"text": "They say the false sky flickered over Leak Street again. People stop looking up. That is the point of it.",
	 "conditions": {}},
	{"text": "Someone saw a goon cannon punch a wall and lose the argument. The wall is being insufferable about it.",
	 "conditions": {}},
	{"text": "The rain is early, late, or lying. Those are the three local weather reports.",
	 "conditions": {}},
	{"text": "A person in a sheet walked out of the dead nook, and the mall decided to continue anyway. Strong survival instinct, this place.",
	 "conditions": {}},
]

# Tone disposition deltas. Matching the NPC's preferred tone helps; the opposite of their
# preference hurts; Normal is always a small safe nudge toward civility.
const TONE_MATCH_BONUS := 4
const TONE_MISMATCH_PENALTY := -3
const TONE_NORMAL_NUDGE := 1

# Spooky Ghost looks like a classic bedsheet ghost (a sheet fused to a borrowed android body).
# These are occasional asides everyday NPCs tack onto a later greeting — running comic relief.
const SHEET_QUIPS: Array = [
	"(They glance at the sheet, decide not to ask, and visibly lose that fight with themselves.)",
	"\"...still going with the sheet, then. Bold. Carry on.\"",
	"\"One of these days you'll explain the sheet. Today is not that day.\"",
	"\"Nice sheet,\" they offer, in the tone of someone with questions and no time for them.",
	"(A long look at the two eyeholes. A longer look pointedly away from them.)",
	"\"You know we can all see the bedsheet, right? Right. Just checking.\"",
]


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


func topic_question(topic_id: String, tab: String = "tell") -> String:
	var t: Dictionary = TOPICS.get(topic_id, {})
	var authored := str(t.get("question", ""))
	if not authored.is_empty():
		return authored
	match tab:
		"work": return "Anything that needs doing?"
		"where": return "Where can I find %s?" % _topic_label(topic_id)
		_: return "Tell me about %s." % _topic_label(topic_id)


# Fires a profile's open_effects once, when the conversation begins (e.g. Vera's heal).
func on_open(npc_id: String) -> void:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	_apply_effects(profile.get("open_effects", []))


func greeting(npc_id: String) -> Dictionary:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var tier := _tier(npc_id)
	# First-meeting "surprised at the sheet ghost" line, shown once per NPC. Tracked by a world
	# flag so it persists and only fires the first time you talk to this NPC.
	var met_flag := "dlg_met_" + npc_id
	var first := not bool(GameState.get_world_flag(met_flag, false))
	var text_value = profile.get("greetings", {})
	if profile.has("first_greeting") and first:
		text_value = profile["first_greeting"]
	GameState.set_world_flag(met_flag, true)
	var text := _resolve_text(text_value, tier)
	var context_aside := _contextual_greeting_aside(npc_id)
	if not context_aside.is_empty():
		text += "\n\n" + context_aside
	# Recurring comic relief: on later visits an everyday NPC (one that authored a first_greeting,
	# so this skips the survivor / spine characters) occasionally can't help remarking on the sheet.
	if not first and profile.has("first_greeting") and randf() < 0.22:
		text += "\n\n" + str(SHEET_QUIPS[randi() % SHEET_QUIPS.size()])
	return {
		"name": str(profile.get("name", npc_id.capitalize())),
		"text": text,
		"tier": tier,
		"mood": _mood_word(tier),
	}


# Returns the keyword buttons for a tab: "tell" (person+thing), "where" (location), "work".
# Each entry: {topic_id, label, state}  state in "known" | "hint".
func category_entries(npc_id: String, tab: String) -> Array:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var npc_topics: Dictionary = profile.get("topics", {})
	var wanted := _categories_for_tab(tab)
	var entries: Array = []

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
		# A topic is a locked "?" cue only if it explicitly authored a `hint` AND is unlearned.
		# Work offers, already-known topics, and plain (no-hint) common-knowledge topics stay askable.
		if cat == "work" or GameState.has_topic(topic_id) or not entry.has("hint"):
			entries.append({"topic_id": topic_id, "label": _topic_label(topic_id), "state": "known"})
		else:
			entries.append({"topic_id": topic_id, "label": "? " + str(entry.get("hint", "something")), "state": "hint"})

	entries.sort_custom(func(a, b): return str(a["label"]) < str(b["label"]))
	return entries


# Ask a topic. Applies effects, learns the topic if it was a hint, and returns the response line.
func ask(npc_id: String, topic_id: String) -> Dictionary:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var npc_topics: Dictionary = profile.get("topics", {})
	var speaker_name := str(profile.get("name", npc_id.capitalize()))
	var tier := _tier(npc_id)

	if not npc_topics.has(topic_id):
		# Known to the player but not to this NPC — disposition-flavoured shrug.
		GameState.learn_topic(topic_id)  # asking still counts as "knowing" it
		return {"name": speaker_name, "text": _resolve_text(profile.get("unknown_line", "I would not know."), tier)}

	var entry: Dictionary = npc_topics[topic_id]
	# Learning happens on ask (this is how `?` hints enter the codex).
	GameState.learn_topic(topic_id)
	for taught: String in entry.get("teaches", []):
		GameState.learn_topic(str(taught))
	_apply_effects(entry.get("effects", []))

	if entry.has("dynamic_text"):
		return {"name": speaker_name, "text": _resolve_dynamic_text(str(entry["dynamic_text"]), tier)}
	return {"name": speaker_name, "text": _resolve_text(entry.get("text", "..."), tier)}


func rumor(npc_id: String) -> Dictionary:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var speaker_name := str(profile.get("name", npc_id.capitalize()))
	var matching_news: Array = _contextual_news_lines(npc_id)
	var matching_profile_rumors: Array = []
	for r: Dictionary in profile.get("rumors", []):
		if _check_conditions(r.get("conditions", {})):
			matching_profile_rumors.append(r)
	var matching_city_rumors: Array = []
	for r: Dictionary in CITY_RUMORS:
		if _check_conditions(r.get("conditions", {})):
			matching_city_rumors.append(r)
	var pool: Array = []
	pool.append_array(matching_news)
	pool.append_array(matching_profile_rumors)
	pool.append_array(matching_city_rumors)
	if not pool.is_empty():
		var picked = pool[randi() % pool.size()]
		if typeof(picked) != TYPE_DICTIONARY:
			return {"name": speaker_name, "text": str(picked)}
		var picked_profile: Dictionary = picked
		for taught: String in picked_profile.get("teaches", []):
			GameState.learn_topic(str(taught))
		return {"name": speaker_name, "text": str(picked_profile.get("text", ""))}
	return {"name": speaker_name, "text": "Nothing worth repeating. That is its own kind of news down here."}


func services(npc_id: String) -> Array:
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	return profile.get("services", []).duplicate()


func _contextual_greeting_aside(npc_id: String) -> String:
	var lines := _contextual_news_lines(npc_id, false)
	if lines.is_empty():
		return ""
	return str(lines[0])


func _contextual_news_lines(npc_id: String, include_idle_sky := true) -> Array:
	var lines: Array = []
	var profile: Dictionary = NPC_PROFILES.get(npc_id, {})
	var faction := str(profile.get("faction", ""))
	var event_id := str(GameState.get_world_flag("active_world_event", "clear"))
	match event_id:
		"toxic_rain":
			lines.append("The false sky is leaking poison again. People are checking masks before names.")
		"power_sag":
			lines.append("The artificial sky is dimming at the corners. When the ceiling gets tired, everyone below it starts counting batteries.")
		"lan_outage":
			lines.append("The ceiling ads are stuttering and the camera feeds have gaps. System X calls that opportunity; everybody else calls it a reason to hurry.")
		_:
			if include_idle_sky:
				if bool(GameState.get_world_flag("hub_power_restored", false)):
					lines.append("The false sky is still fake, but at least the lights behind it no longer sound like they are begging.")
				else:
					lines.append("The false sky keeps pretending everything is normal. Down here, normal flickers and asks for parts.")

	if not GameState.active_job_id.is_empty():
		var job: Dictionary = GameState.get_active_job_data()
		var destination := str(job.get("destination", "the dead floors"))
		if GameState.is_job_objective_done(GameState.active_job_id):
			lines.append("Word is you finished the Cooters job in %s. Marbles will pretend not to be pleased until the register opens." % destination)
		else:
			lines.append("People heard you took work in %s. That place has started appearing in conversations with the kind of pause people use for bad stairs." % destination)

	if bool(GameState.get_world_flag("ward7_experiment_docs_found", false)):
		lines.append("Ward 7 is not just a rumor anymore. People say 'green report' now like it means 'grave with a login screen.'")
	elif bool(GameState.get_world_flag("ward7_entered", false)):
		lines.append("You went into Ward 7 and came back carrying the room with you. Even people who do not know the name can feel it.")

	if bool(GameState.get_world_flag("rocker_fellar_defeated", false)):
		lines.append("Rocker Fellar went quiet. The lower pipes stopped humming bass through everybody's teeth, which is the closest this place gets to a holiday.")
	if bool(GameState.get_world_flag("hub_cistern_connected", false)):
		lines.append("Clean water changed the room temperature of the whole hub. People are learning to drink without bracing for punishment.")
	if bool(GameState.get_world_flag("hub_lan_restored", false)):
		lines.append("The LAN tap is alive. System X sees farther now, and the cameras seem offended by the competition.")
	if bool(GameState.get_world_flag("atrium_cleared", false)):
		lines.append("The atrium paths are open. People keep walking through the center just because they can.")

	_append_reputation_news(lines, faction)
	return lines


func _append_reputation_news(lines: Array, listener_faction: String) -> void:
	var system_x_rep := int(GameState.reputation.get("System X", 0))
	var gatebox_rep := int(GameState.reputation.get("Gatebox Corporation", 0))
	var torai_rep := int(GameState.reputation.get("Wan Moa Torai", 0))
	var linda_rep := int(GameState.reputation.get("Linda", 0))

	if system_x_rep >= 4:
		lines.append("System X is saying your name with less static in it. Around here, that is practically affection.")
	elif system_x_rep <= -2:
		lines.append("System X has you filed under 'useful risk.' That folder is thicker than you want it to be.")

	if torai_rep >= 3:
		lines.append("Wan Moa Torai likes you, which means the ledger smiles when you enter the room. Do not smile back without reading the margin notes.")
	elif torai_rep <= -2:
		lines.append("Torai clerks are using your name like a balance due. That is a bad kind of famous.")

	if gatebox_rep >= 2:
		lines.append("Gatebox systems have started greeting you like a valued irregularity. Nobody trusts a polite door down here.")
	elif gatebox_rep <= -2:
		lines.append("Gatebox attention is souring around you. Cameras tilt a little faster when the sheet passes under them.")

	if linda_rep >= 2:
		lines.append("Linda's metrics are warm around you. Warmth from that direction usually means the cage has found a comfortable shape.")
	elif linda_rep <= -2:
		lines.append("Linda's wellness logic has you flagged as disruptive. In the lower city, that almost sounds like a compliment.")

	if not listener_faction.is_empty():
		var listener_rep := int(GameState.reputation.get(listener_faction, 0))
		if listener_rep >= 3:
			lines.append("%s people are giving you the small nod now. Not trust exactly, but trust's cheaper cousin." % listener_faction)
		elif listener_rep <= -2:
			lines.append("%s people have started measuring doorways when you enter. Reputation travels ahead of you." % listener_faction)


func _resolve_dynamic_text(text_id: String, tier: String) -> String:
	match text_id:
		"active_job_brief":
			return _active_job_brief(tier)
	return "I had that note written down, then the board ate it. Ask me again after I threaten the chalk."


func _active_job_brief(tier: String) -> String:
	var job: Dictionary = GameState.get_active_job_data()
	if job.is_empty():
		return "No current mission. Board's on the wall when you want a fresh mistake."
	var title := str(job.get("title", "the job"))
	var destination := str(job.get("destination", "the dead floors"))
	var giver := str(job.get("giver", "Cooters"))
	var faction := str(job.get("faction", ""))
	var rival := str(job.get("rival_faction", ""))
	var reward := str(job.get("reward_text", "bar credit"))
	var source := giver
	if not faction.is_empty() and faction != giver:
		source = "%s, through %s" % [giver, faction]
	var route_hint := _marbles_route_hint(str(job.get("destination_id", "")), destination)
	var job_hint := _marbles_job_hint(job)
	var threat_hint := _marbles_threat_hint(rival)

	if GameState.is_job_objective_done(GameState.active_job_id):
		match tier:
			"warm":
				return "%s is already limping behind you like a solved problem. Bring it to the bar and I will make the register cough up %s. And yes, that is me being proud. Briefly." % [title, reward]
			"cold":
				return "%s is done. Hand over the proof, take %s, and do not make me chase a receipt across my own floor." % [title, reward]
			_:
				return "You got what the job wanted. Bring %s back to me before the dead floors decide it belongs to them. Payout is %s." % [title, reward]

	match tier:
		"warm":
			return "%s came through %s, which means it is either important or embarrassing. %s %s %s Come back with the proof and enough of yourself to spend %s." % [title, source, route_hint, job_hint, threat_hint, reward]
		"cold":
			return "%s. %s %s %s Pays %s. Try not to make me write your name on the bad wall." % [title, route_hint, job_hint, threat_hint, reward]
		_:
			return "%s, from %s. %s %s %s Bring proof back here and the board pays %s." % [title, source, route_hint, job_hint, threat_hint, reward]


func _marbles_job_hint(job: Dictionary) -> String:
	var objective_type := str(job.get("objective_type", "find"))
	var destination := str(job.get("destination", "the dead floors"))
	match objective_type:
		"find":
			var item := str(job.get("objective_item", "the marked thing"))
			return "You're looking for %s; the right piece is usually the one humming, leaking, or pretending it was always part of the room." % item
		"kill_loot":
			var loot := str(job.get("target_loot_label", job.get("target_loot", "the salvage")))
			return "This one's not a polite pickup. Take %s off whoever is guarding %s, preferably after they stop arguing with bullets." % [loot, destination]
		"deliver":
			var parcel := str(job.get("deliver_item", "the parcel"))
			return "Keep %s on you until you find the drop point. Do not set it down somewhere dramatic; these floors adopt unattended objects." % parcel
		"escort":
			var escort := str(job.get("escort_label", "the stranded asset"))
			return "Find %s and walk them back to the entrance. If they panic, let them; panic still has feet." % escort
	return str(job.get("objective", "Do the job, then come back upright."))


func _marbles_route_hint(destination_id: String, destination: String) -> String:
	match destination_id:
		"pipe_utility_tunnels":
			return "Take the Leak Street gate to the Pipe Utility Tunnels; follow the wet metal and check side bends before the pipes start making church noises."
		"dead_food_court_bloom":
			return "Take the Leak Street gate to the Dead Food Court Bloom; menu boards lie, plants grab ankles, and the useful stuff hides near old service counters."
		"water_reclamation_cistern":
			return "Take the Leak Street gate to the Water Reclamation Cistern; stay above the worst water when you can and search around the pump guts."
		"collapsed_service_atrium":
			return "Take the Leak Street gate to the Collapsed Service Atrium; look for relay junk and service decks where the mall forgot which way was up."
	if destination.is_empty():
		return "Use the Leak Street gate and keep your eyes lower than the false sky."
	return "Use the Leak Street gate, pick %s, and trust the signs only until they start sounding confident." % destination


func _marbles_threat_hint(rival: String) -> String:
	match rival:
		"Splice":
			return "If the Splice show up, break the parts that make them fast before you debate the rest of the anatomy."
		"Gatebox", "Gatebox Corporation":
			return "If Gatebox is there, use walls like they owe you money; their cannons hate corners and their arms hate being shot off."
		"Big Gates", "Big Gates Foundation":
			return "If Big Gates sent talent, do not stand in a straight line and do not let the music tell you where to die."
		"Wan Moa Torai":
			return "If Torai contests it, read every demand like a knife with punctuation and keep one eye on the exit."
	if rival.is_empty():
		return "If something new starts breathing nearby, assume it signed the guest book in blood."
	return "%s has fingerprints on this. That means company, and company means cover first, curiosity second." % rival


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
	if entry.has("requires_flag_false_any"):
		for flag in entry.get("requires_flag_false_any", []):
			if bool(GameState.get_world_flag(str(flag))):
				return false
	if entry.has("requires_quest") and not GameState.is_quest_completed(str(entry["requires_quest"])):
		return false
	if entry.has("requires_quest_not") and GameState.is_quest_completed(str(entry["requires_quest_not"])):
		return false
	if entry.has("requires_rep_gte"):
		var rep_req: Array = entry.get("requires_rep_gte", [])
		if rep_req.size() >= 2 and int(GameState.reputation.get(str(rep_req[0]), 0)) < int(rep_req[1]):
			return false
	if entry.has("requires_job_active") and bool(entry["requires_job_active"]) != (not GameState.active_job_id.is_empty()):
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
