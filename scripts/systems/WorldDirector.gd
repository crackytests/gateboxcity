extends Node

signal world_state_changed(summary: String)

const REGION_FADED_ATRIUM := "faded_atrium"
const REGION_SUB_BASEMENT := "sub_sub_basement"

const EVENT_CLEAR := "clear"
const EVENT_TOXIC_RAIN := "toxic_rain"
const EVENT_POWER_SAG := "power_sag"
const EVENT_LAN_OUTAGE := "lan_outage"

const GENERATOR_STABLE := "stable"
const GENERATOR_SAGGING := "sagging"
const GENERATOR_OVERLOADED := "overloaded"
const GENERATOR_OFFLINE := "offline"

const REGIONS := {
	REGION_FADED_ATRIUM: {
		"name": "Faded Atrium",
		"brief": "Counterfeit mall comfort under a leaking artificial sky, still insisting it is retail therapy.",
		"pressure": "stable, watched",
	},
	REGION_SUB_BASEMENT: {
		"name": "Sub-Sub-Basement",
		"brief": "Leak Street, one wet patchwork settlement lane pretending the larger lower-city sprawl is not breathing behind it.",
		"pressure": "crowded, watched, larger than it looks",
	},
}

const EVENTS := {
	EVENT_CLEAR: {
		"name": "clear",
		"hud": "SKY  false daylight",
		"brief": "The artificial ceiling is pretending to be weather and doing community theater about daylight.",
	},
	EVENT_TOXIC_RAIN: {
		"name": "toxic rain",
		"hud": "SKY  toxic rain",
		"brief": "Industrial runoff is falling from the fake sky. Shelter and sealed gear matter unless you enjoy becoming a cautionary texture.",
	},
	EVENT_POWER_SAG: {
		"name": "power sag",
		"hud": "GRID  sagging",
		"brief": "Generators are coughing. Doors, lights, and cheap cybernetics are unreliable in that personal way machines get.",
	},
	EVENT_LAN_OUTAGE: {
		"name": "LAN outage",
		"hud": "GRID  hoodlum outage",
		"brief": "Hoodlums hijacked the grid for an illegal LAN party. Surveillance is blind in patches and pretending this is beneath it.",
	},
}

const TRAVEL_EVENT_CARDS := [
	{
		"id": "clear",
		"title": "Clear Run",
		"event": EVENT_CLEAR,
		"weight": 3,
		"text": "The route opens clean. The fake sky watches without spending weather, generous little ceiling that it is.",
	},
	{
		"id": "toxic_rain",
		"title": "Toxic Rain",
		"event": EVENT_TOXIC_RAIN,
		"weight": 2,
		"text": "The ceiling starts leaking industrial weather before you reach the turnstiles. Timing like a heckler with plumbing access.",
	},
	{
		"id": "power_sag",
		"title": "Power Sag",
		"event": EVENT_POWER_SAG,
		"weight": 2,
		"text": "The grid coughs. Streetlights dim and every terminal sounds like it owes money to someone with thumbs.",
	},
	{
		"id": "lan_outage",
		"title": "LAN Outage",
		"event": EVENT_LAN_OUTAGE,
		"weight": 1,
		"text": "Hoodlum packets flood the route. Cameras blink out in suspiciously useful order, very tragic, thoughts and prayers.",
	},
	{
		"id": "quiet_shortcut",
		"title": "Quiet Shortcut",
		"event": EVENT_CLEAR,
		"weight": 1,
		"text": "A maintenance door gives up. No one admits they saw you use it, which is the closest this city gets to privacy.",
	},
]

var NAMED_CARDS: Dictionary = {
	"pipe_blood_sample_exit": {
		"id": "pipe_blood_sample_exit", "title": "Pipe Condition Report",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "pipe_blood_sample"},
		"effects": [], "expires_after": 1, "tags": ["pipe_blood_sample_active"],
		"speaker": "Marbles",
		"text": "The blood moves upward on odd days. Today is odd. Sealed bulb or it wins the argument.",
	},
	"pipe_blood_sample_travel": {
		"id": "pipe_blood_sample_travel", "title": "Pipe Pressure Spike",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "pipe_blood_sample"},
		"effects": [{"type": "set_event", "event_id": "toxic_rain"}],
		"expires_after": -1, "tags": ["pipe_blood_sample_active"],
		"speaker": "System X",
		"text": "Pipe pressure elevated in the utility corridor. The ceiling has decided today is billable.",
	},
	"pipe_blood_sample_return": {
		"id": "pipe_blood_sample_return", "title": "Pipe Blood Catalogued",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": [],
		"speaker": "System X",
		"text": "Sample catalogued. It moved three times in unspecified directions. Marbles is quietly excited and professionally refusing to admit it.",
	},
	"ratchet_saint_exit": {
		"id": "ratchet_saint_exit", "title": "Saint Ratchet Directions",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "ratchet_saint"},
		"effects": [], "expires_after": 1, "tags": ["ratchet_saint_active"],
		"speaker": "Marbles",
		"text": "Gideon says Saint Ratchet hums when it is close to the surface. Bolt-pitch harmonics. Go toward them.",
	},
	"ratchet_saint_travel": {
		"id": "ratchet_saint_travel", "title": "Pipe Chapel Signal",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "ratchet_saint"},
		"effects": [], "expires_after": -1, "tags": ["ratchet_saint_active"],
		"speaker": "Pipe Father Gideon",
		"text": "The Saint fell because the pipe trusted weight it could not carry. That is a sermon and also directions.",
	},
	"ratchet_saint_return": {
		"id": "ratchet_saint_return", "title": "Saint Ratchet Returned",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [{"type": "set_flag", "flag": "saint_ratchet_returned", "value": true}],
		"expires_after": 0, "tags": [],
		"speaker": "Pipe Father Gideon",
		"text": "Saint Ratchet is returned. The generator hums different. Do not tell Wan Moa Torai it is doing anything miraculous or they will invoice the miracle.",
	},
	"listen_pipes_exit": {
		"id": "listen_pipes_exit", "title": "Pipe Frequency Tip",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "listen_to_the_pipes"},
		"effects": [], "expires_after": 1, "tags": ["listen_to_the_pipes_active"],
		"speaker": "Ladderboy",
		"text": "The pipes get loud around the drain at third power cycle. Recorder needs to be within two meters or all you get is institutional breathing.",
	},
	"listen_pipes_travel": {
		"id": "listen_pipes_travel", "title": "LAN Pipe Tap",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "listen_to_the_pipes"},
		"effects": [{"type": "set_event", "event_id": "lan_outage"}],
		"expires_after": -1, "tags": ["listen_to_the_pipes_active"],
		"speaker": "System X",
		"text": "LAN spike in the utility corridor. Someone else is also listening to the pipes today. First one with a recording wins, probably.",
	},
	"listen_pipes_return": {
		"id": "listen_pipes_return", "title": "Pipes Catalogue Updated",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [{"type": "set_flag", "flag": "pipes_catalogue_updated", "value": true}],
		"expires_after": 0, "tags": [],
		"speaker": "System X",
		"text": "The recording is in the catalogue. The pipes said something in three distinct registers. Two were complaints. One was a warning we are still translating.",
	},
	"food_court_exit": {
		"id": "food_court_exit", "title": "Bloom Route Advice",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "food_court_filter"},
		"effects": [], "expires_after": 1, "tags": ["food_court_filter_active"],
		"speaker": "Marbles",
		"text": "The bloom is worst near the condiment bar. Upper ring is slower but your ankles survive at the same rate your dignity does, which is one to one.",
	},
	"food_court_travel": {
		"id": "food_court_travel", "title": "Bloom Grid Interference",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "food_court_filter"},
		"effects": [{"type": "set_event", "event_id": "power_sag"}],
		"expires_after": -1, "tags": ["food_court_filter_active"],
		"speaker": "System X",
		"text": "The bloom has worked into the grid junction near the food court. Power is unreliable. Cheap cybernetics will complain about this personally.",
	},
	"food_court_return": {
		"id": "food_court_return", "title": "Torai Filter Credit",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": [],
		"speaker": "Kiki Baja",
		"text": "Clean filter out of the bloom court. Torai has already opened a ledger entry for the clean water credit. Gratitude here is shaped like paperwork.",
	},
	"cistern_exit": {
		"id": "cistern_exit", "title": "Live Conduit Warning",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "cistern_pump_heart"},
		"effects": [], "expires_after": 1, "tags": ["cistern_pump_heart_active"],
		"speaker": "Marbles",
		"text": "The live conduit is real. Do not step in the water near it. Torai will say they are sorry and then invoice the emergency response.",
	},
	"cistern_travel": {
		"id": "cistern_travel", "title": "Torai Lease Check",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "cistern_pump_heart"},
		"effects": [{"type": "set_event", "event_id": "lan_outage"}],
		"expires_after": -1, "tags": ["cistern_pump_heart_active"],
		"speaker": "Brickmouth Ronnie",
		"text": "Torai network check on the pump heart lease just went active. They are watching the approach. Surveillance blind spot is your friend today.",
	},
	"cistern_return": {
		"id": "cistern_return", "title": "Torai Lease Cleared",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [{"type": "add_rep", "faction": "Wan Moa Torai", "amount": 1}],
		"expires_after": 0, "tags": [],
		"speaker": "Brickmouth Ronnie",
		"text": "Pump core returned. Torai cleared the lease flag. Your ledger is one line shorter, which is as close to forgiveness as the office gets.",
	},
	"atrium_relay_exit": {
		"id": "atrium_relay_exit", "title": "Catwalk Warning",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "atrium_relay_echo"},
		"effects": [], "expires_after": 1, "tags": ["atrium_relay_echo_active"],
		"speaker": "Marbles",
		"text": "The catwalk above the sludge gap is load-bearing until it decides it is not. Trust the north side. The south side has been making its own decisions for three months.",
	},
	"atrium_relay_travel": {
		"id": "atrium_relay_travel", "title": "Relay Grid Interference",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "atrium_relay_echo"},
		"effects": [{"type": "set_event", "event_id": "power_sag"}],
		"expires_after": -1, "tags": ["atrium_relay_echo_active"],
		"speaker": "System X",
		"text": "The relay is still broadcasting. Grid sag in the atrium approach is interference from the signal, not malfunction. Probably.",
	},
	"atrium_relay_return": {
		"id": "atrium_relay_return", "title": "Relay Data Logged",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [{"type": "set_flag", "flag": "atrium_relay_data_logged", "value": true}],
		"expires_after": 0, "tags": [],
		"speaker": "System X",
		"text": "Relay packet received. The mall is still saying something in a frequency that predates the corporate reformat. We are not sure if it is a warning or a customer service survey.",
	},
	"splice_pipes_return": {
		"id": "splice_pipes_return", "title": "Splice In The Tunnels",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": ["splice_encounter"],
		"speaker": "Marbles",
		"text": "One in the west passage. Former maintenance, Torai integration frame still running whatever it thinks maintenance is. Did not respond to the safety signal. Did respond to the scrap pistol. In retrospect, same outcome.",
	},
	"splice_bloom_return": {
		"id": "splice_bloom_return", "title": "Splice In The Bloom",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": ["splice_encounter"],
		"speaker": "Marbles",
		"text": "Splice in the growth pit. The bloom had started using it as a route anchor. Whatever Torai installed in it, the plants do not mind the frame. This is either biologically interesting or structurally concerning. I am going with both.",
	},
	"splice_cistern_return": {
		"id": "splice_cistern_return", "title": "Splice Near The Water",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": ["splice_encounter"],
		"speaker": "Marbles",
		"text": "One on the east walkway. The Torai frame kept it dry. Water does not bother them because Torai sealed the integration points on install. At least the contract waterproofed.",
	},
	"splice_atrium_return": {
		"id": "splice_atrium_return", "title": "Splice Below The Catwalk",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": ["splice_encounter"],
		"speaker": "System X",
		"text": "Splice on the atrium ground floor. Below the catwalk. Below the sludge line. This is not reassurance. This is a current arrangement that the sludge does not care about.",
	},
	"splice_travel_warning": {
		"id": "splice_travel_warning", "title": "Splice Activity",
		"contexts": ["travel"], "weight": 1,
		"conditions": {}, "effects": [], "expires_after": -1, "tags": ["splice_ambient"],
		"speaker": "Ladderboy",
		"text": "Movement near the utility junction. Torai integration frame, organic component still present. They remember walls. They do not remember you. Aim for the Graft Shell.",
	},
	"hub_power_exit": {
		"id": "hub_power_exit", "title": "Generator Run",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"flag_true": "quest_hub_power_active"},
		"effects": [], "expires_after": 1, "tags": ["hub_power_active"],
		"speaker": "Mister Static",
		"text": "The coupling is in the basement. I have been fixing it with tape for six weeks. It deserves better. So does the tape.",
	},
	"hub_power_return": {
		"id": "hub_power_return", "title": "Generator Online",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {},
		"effects": [{"type": "set_flag", "flag": "hub_power_restored", "value": true}],
		"expires_after": 0, "tags": [],
		"speaker": "Mister Static",
		"text": "Generator is stable. The lights are full and everyone is acting like they cannot believe they live here. Some of them still cannot. That is progress.",
	},
	"hub_lan_exit": {
		"id": "hub_lan_exit", "title": "LAN Tap Run",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"flag_true": "quest_hub_lan_active"},
		"effects": [{"type": "set_event", "event_id": "lan_outage"}],
		"expires_after": 1, "tags": ["hub_lan_active"],
		"speaker": "System X",
		"text": "The tap cable is in the service corridor ceiling panel above the north corridor junction. Hoodlums clipped it during the last LAN party. Bring a splice kit.",
	},
	"hub_lan_return": {
		"id": "hub_lan_return", "title": "LAN Restored",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {},
		"effects": [{"type": "set_flag", "flag": "hub_lan_restored", "value": true}],
		"expires_after": 0, "tags": [],
		"speaker": "System X",
		"text": "LAN is live. I am now watching fourteen feeds I was not watching before. Three of them are concerning. I will tell you when it is actionable.",
	},
	"coil_invitation_card": {
		"id": "coil_invitation_card", "title": "Velvet Coil Message",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {"flag_true": "coil_met_in_tunnels"},
		"effects": [], "expires_after": 1, "tags": ["coil_invitation"],
		"speaker": "Velvet Coil",
		"text": "Tell them I am still thinking about the invitation. I have conditions. Most of them are about the acoustics of the space. The rest are about Torai.",
	},
	"hub_cistern_exit": {
		"id": "hub_cistern_exit", "title": "Conduit Run",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"flag_true": "quest_hub_cistern_active"},
		"effects": [], "expires_after": 1, "tags": ["hub_cistern_active"],
		"speaker": "Vera",
		"text": "The junction point is on the west walkway of the cistern. Torai has a monitoring node there. Do not let it log you. Clean water is worth the careful approach.",
	},
	"hub_cistern_return": {
		"id": "hub_cistern_return", "title": "Hub Water Connected",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {},
		"effects": [{"type": "set_flag", "flag": "hub_cistern_connected", "value": true}],
		"expires_after": 0, "tags": [],
		"speaker": "Vera",
		"text": "Water is running. I ran three purity tests. It passed all three, which is two more than I expected. I am not going to question this.",
	},
	"hub_ambient_phase1_a": {
		"id": "hub_ambient_phase1_a", "title": "Generator Cough",
		"contexts": ["hub_return"], "weight": 1,
		"conditions": {"flag_false": "hub_power_restored"},
		"effects": [], "expires_after": -1, "tags": ["hub_ambient"],
		"speaker": "Mister Static",
		"text": "The generator coughed twice while you were out. I told it things would improve. It did not seem convinced. I am not either but I kept that part private.",
	},
	"hub_ambient_phase1_b": {
		"id": "hub_ambient_phase1_b", "title": "Offline",
		"contexts": ["hub_return"], "weight": 1,
		"conditions": {"flag_false": "hub_lan_restored"},
		"effects": [], "expires_after": -1, "tags": ["hub_ambient"],
		"speaker": "System X",
		"text": "I cannot see anything from here. This is not a complaint, it is a capability summary. Please fix the LAN before I have to say this again.",
	},
	"hub_ambient_phase2_a": {
		"id": "hub_ambient_phase2_a", "title": "Lights Are On",
		"contexts": ["hub_return"], "weight": 1,
		"conditions": {"flag_true": "hub_phase_2"},
		"effects": [], "expires_after": -1, "tags": ["hub_ambient"],
		"speaker": "Mister Static",
		"text": "Three people asked me if we were staying. I said yes. Two of them started carrying things in from the corridor. I think we are staying.",
	},
	"hub_ambient_phase2_b": {
		"id": "hub_ambient_phase2_b", "title": "Torai Desk Note",
		"contexts": ["hub_return"], "weight": 1,
		"conditions": {"flag_true": "hub_phase_2"},
		"effects": [], "expires_after": -1, "tags": ["hub_ambient"],
		"speaker": "Kiki Baja",
		"text": "Wan Moa Torai sent a message. It says they are aware of our location and are interested in providing services. It is formatted as a sales letter. I am choosing to read it as a threat.",
	},
	"hub_ambient_phase3_a": {
		"id": "hub_ambient_phase3_a", "title": "Bar is Open",
		"contexts": ["hub_return"], "weight": 1,
		"conditions": {"flag_true": "hub_phase_3"},
		"effects": [], "expires_after": -1, "tags": ["hub_ambient"],
		"speaker": "Marbles",
		"text": "The bar opened. I do not think any of us thought we would get here. I am going to celebrate this professionally and also with a drink.",
	},
	"hub_ambient_phase3_b": {
		"id": "hub_ambient_phase3_b", "title": "Velvet Coil Radio",
		"contexts": ["hub_return"], "weight": 1,
		"conditions": {"flag_true": "coil_invitation_accepted"},
		"effects": [], "expires_after": -1, "tags": ["hub_ambient"],
		"speaker": "Velvet Coil",
		"text": "I set up the radio. The acoustics here are acceptable. I was not going to say that unless they were. They are. That is the extent of my enthusiasm. For now.",
	},
	"hub_pipe_valve_note": {
		"id": "hub_pipe_valve_note", "title": "Pipe Pressure Note",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {"flag_true": "pipe_valve_used"},
		"effects": [], "expires_after": 1, "tags": [],
		"speaker": "Pipe Father Gideon",
		"text": "You bled the pressure valve. The pipes are quieter. The congregation thinks it is a sign. I told them it was maintenance. They think that too is a sign.",
	},
	"hub_spore_vent_note": {
		"id": "hub_spore_vent_note", "title": "Bloom Court Vented",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {"flag_true": "spore_vent_used"},
		"effects": [], "expires_after": 1, "tags": [],
		"speaker": "Marbles",
		"text": "Spore count in the food court is down forty percent since the vent panel. I know because I am tracking it. I started tracking it because I was concerned. I am less concerned now.",
	},
	"hub_atrium_gate_note": {
		"id": "hub_atrium_gate_note", "title": "Hardlight Gate Opened",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {"flag_true": "atrium_gate_opened"},
		"effects": [], "expires_after": 1, "tags": [],
		"speaker": "System X",
		"text": "Hardlight bridge is active in the service atrium. The gate panel is Gatebox tech. If they are logging access, they know. I am logging that they might be logging.",
	},
	"rocker_fellar_exit": {
		"id": "rocker_fellar_exit", "title": "Deep Lift",
		"contexts": ["district_exit"], "weight": 3,
		"conditions": {"flag_true": "quest_rocker_fellar_active"},
		"effects": [], "expires_after": 1, "tags": ["rocker_fellar"],
		"speaker": "System X",
		"text": "The service lift goes deep. Fellar's fortress is built inside an old performance complex that the Big Gates Foundation repurposed into a soul-processing venue. The acoustics are intentional. Bring ear protection and a healthy disrespect for authority.",
	},
	"rocker_fellar_return": {
		"id": "rocker_fellar_return", "title": "General Down",
		"contexts": ["hub_return"], "weight": 5,
		"conditions": {"flag_true": "rocker_fellar_defeated"},
		"effects": [
			{"type": "set_flag", "flag": "quest_rocker_fellar_complete", "value": true},
			{"type": "add_rep", "faction": "System X", "amount": 3},
			{"type": "add_rep", "faction": "Gatebox Corporation", "amount": -2},
		],
		"expires_after": 0, "tags": [],
		"speaker": "System X",
		"text": "Rocker Fellar is offline. His soul batteries are empty. The contract ledger you found links Big Gates procurement to Gatebox Corporation logistics and Wan Moa Torai debt collection. This is not a small thing. This is the first crack in the foundation.",
	},

	# ── Phase 2: drift-reaction ambient cards ────────────────────────
	"drift_noticed_return": {
		"id": "drift_noticed_return", "title": "Something Off",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {"flag_true": "drift_noticed", "flag_false": "drift_uncanny"},
		"effects": [], "expires_after": 2, "tags": ["drift_reaction"],
		"speaker": "Marbles",
		"text": "You walk different now. Quieter in the joints, louder in the spaces between. I am not saying it is bad. I am saying I counted your footsteps and one of them was not yours.",
	},
	"drift_uncanny_warning": {
		"id": "drift_uncanny_warning", "title": "Drift Advisory",
		"contexts": ["district_exit", "hub_return"], "weight": 3,
		"conditions": {"flag_true": "drift_uncanny", "flag_false": "high_drift"},
		"effects": [], "expires_after": 2, "tags": ["drift_reaction"],
		"speaker": "System X",
		"text": "Your hardware-to-meat ratio crossed a line corporate actuaries care about. Gatebox flags people who read like you do. Keep moving and keep your sleeves down.",
	},
	"high_drift_surveillance": {
		"id": "high_drift_surveillance", "title": "Preservation Interest",
		"contexts": ["travel"], "weight": 4,
		"conditions": {"flag_true": "high_drift"},
		"effects": [], "expires_after": -1, "tags": ["drift_reaction"],
		"speaker": "Gatebox Corporation",
		"text": "Citizen, your wellness profile shows extensive optimization. The Preservation Directive would like to schedule a complimentary review. Please remain where our cameras can find you.",
	},

	# ── Ward 7 (Comfort Annexe) fallout ──────────────────────────────
	"big_gates_sweep": {
		"id": "big_gates_sweep", "title": "Big Gates Sweep",
		"contexts": ["travel", "district_exit"], "weight": 4,
		"conditions": {}, "effects": [], "expires_after": -1, "tags": ["ward7"],
		"speaker": "System X",
		"text": "Movement on the Ward 7 line. Big Gates sent a team to find out why their installation went quiet. They are looking for the reason it stopped reporting. The reason is you.",
	},
	"linda_wellness_check": {
		"id": "linda_wellness_check", "title": "Wellness Check",
		"contexts": ["travel", "district_exit", "hub_return"], "weight": 4,
		"conditions": {}, "effects": [], "expires_after": -1, "tags": ["ward7"],
		"speaker": "Linda",
		"text": "Ward 7 has stopped reporting. That is unusual. I am sending someone to confirm everyone there is still comfortable. I do hope you have not been making people uncomfortable.",
	},

	# ── Interactive event cards (refactor §6) — resolved via EventCardUI + 2d6 checks ──
	"torai_demand_core": {
		"id": "torai_demand_core", "contexts": ["district_exit", "travel"], "weight": 6,
		"faction": "Wan Moa Torai", "conditions": {},
		"title": "A Torai Collector", "speaker": "Wan Moa Torai",
		"body": "A collector peels off the gate ramp, palm already out. \"That contract you took — there is a tithe on it. Company courtesy. You understand courtesy.\"",
		"choices": [
			{"label": "Pay the tithe (5 Wan Notes)",
				"text": "You hand it over. The collector smiles like a closing drawer and is gone.",
				"effects": [{"type": "wan_notes", "amount": -5}, {"type": "add_rep", "faction": "Wan Moa Torai", "amount": 1}]},
			{"label": "Talk it down", "check": {"attribute": "EMP", "difficulty": 8, "tag": "persuade"},
				"success": {"text": "You frame it as future business. They nod, slow. \"This time.\"",
					"effects": [{"type": "add_rep", "faction": "Wan Moa Torai", "amount": 1}]},
				"failure": {"text": "Your charm bounces off the ledger in their eyes. They make a note. The note has your face on it.",
					"effects": [{"type": "add_rep", "faction": "Wan Moa Torai", "amount": -1}, {"type": "add_card", "card_id": "torai_ambush"}]}},
			{"label": "Refuse, hand on your weapon", "check": {"attribute": "WIL", "difficulty": 9, "tag": "intimidate"},
				"crit": {"text": "You hold their stare until they blink first. Word will spread that you do not pay.",
					"effects": [{"type": "add_rep", "faction": "Wan Moa Torai", "amount": -1}]},
				"success": {"text": "They raise both hands and step back. \"No need to be dramatic.\"", "effects": []},
				"fumble": {"text": "Your voice cracks. They take it personally, and the alley takes it for them.",
					"effects": [{"type": "damage", "amount": 12.0}, {"type": "add_card", "card_id": "torai_ambush"}]},
				"failure": {"text": "They were not asking. A pipe wrench finds your ribs on the way past.",
					"effects": [{"type": "damage", "amount": 8.0}, {"type": "add_card", "card_id": "torai_ambush"}]}},
		],
		"expires_after": 1, "tags": ["torai_thread"],
	},
	"torai_ambush": {
		"id": "torai_ambush", "contexts": ["travel"], "weight": 8,
		"faction": "Wan Moa Torai", "conditions": {},
		"title": "Collections, In Person", "speaker": "Wan Moa Torai",
		"body": "Two of Torai's people are waiting where the corridor narrows. \"You skipped a payment. We added a late fee. The late fee is us.\"",
		"choices": [
			{"label": "Buy your way clear (10 Wan Notes)",
				"text": "Notes change hands. The debt resets to merely enormous.",
				"effects": [{"type": "wan_notes", "amount": -10}]},
			{"label": "Slip past them", "check": {"attribute": "AGL", "difficulty": 9, "tag": "flee"},
				"success": {"text": "You are three corners away before they finish their threat.", "effects": []},
				"failure": {"text": "A hand closes on your collar. They drag you back into the open and square up.",
					"effects": [{"type": "damage", "amount": 5.0}, {"type": "spawn_enemies", "enemies": ["goon", "goon"]}]}},
			{"label": "Stand and fight", "check": {"attribute": "STR", "difficulty": 9, "tag": "force"},
				"success": {"text": "You put one down and the other reconsiders the late-fee policy.",
					"effects": [{"type": "add_rep", "faction": "Wan Moa Torai", "amount": -1}]},
				"failure": {"text": "You swing first and miss the read. Now it is a fight on their terms.",
					"effects": [{"type": "damage", "amount": 6.0}, {"type": "spawn_enemies", "enemies": ["goon", "goon"]}]}},
		],
		"expires_after": 1, "tags": ["torai_thread"],
	},
	"torai_gift": {
		"id": "torai_gift", "contexts": ["hub_return"], "weight": 5,
		"faction": "Wan Moa Torai", "conditions": {},
		"title": "A Torai Courtesy", "speaker": "Wan Moa Torai",
		"body": "A courier leaves a sealed envelope at the atrium gate, bows the precise amount, and is gone. \"Goodwill,\" the note says. \"Non-binding. Mostly.\"",
		"choices": [
			{"label": "Open it", "text": "Wan Notes, and a line in tidy hand: 'Your ledger pleases us. Stay pleasing.'",
				"effects": [{"type": "wan_notes", "amount": 12}]},
			{"label": "Check it for strings first", "check": {"attribute": "PER", "difficulty": 8, "tag": "read"},
				"success": {"text": "You find the tracking thread sewn into the seam, pocket the notes, and burn the thread.",
					"effects": [{"type": "wan_notes", "amount": 12}]},
				"failure": {"text": "You paw it suspiciously, find nothing, and feel rude. You take the money anyway.",
					"effects": [{"type": "wan_notes", "amount": 12}, {"type": "add_rep", "faction": "Wan Moa Torai", "amount": -1}]}},
		],
		"expires_after": 1, "tags": ["torai_thread"],
	},
	"gatebox_checkpoint": {
		"id": "gatebox_checkpoint", "contexts": ["district_exit", "travel"], "weight": 5,
		"faction": "Gatebox Corporation", "conditions": {},
		"title": "Comfort Compliance Check", "speaker": "Gatebox Corporation",
		"body": "A wellness drone descends, pinging your implants with cheerful little chimes. \"Citizen, your optimization profile requires a brief comfort audit. This is for your wellbeing.\"",
		"choices": [
			{"label": "Comply and smile", "text": "You let it scan you. It logs you as cooperative and wishes you a safe and monitored day.",
				"effects": [{"type": "add_rep", "faction": "Gatebox Corporation", "amount": 1}, {"type": "add_drift", "amount": 1}]},
			{"label": "Bury it in its own forms", "check": {"attribute": "INT", "difficulty": 8, "tag": "analyze"},
				"success": {"text": "You cite three comfort regulations it has not patched yet. It reboots in confusion.", "effects": []},
				"failure": {"text": "It flags the discrepancy and escalates. A note climbs the chain with your name on it.",
					"effects": [{"type": "add_rep", "faction": "Gatebox Corporation", "amount": -1}, {"type": "add_card", "card_id": "gatebox_enforcers"}]}},
			{"label": "Walk straight past it", "check": {"attribute": "AGL", "difficulty": 9, "tag": "flee"},
				"success": {"text": "You are around the corner before it finishes its sentence.", "effects": []},
				"failure": {"text": "It shrieks a wellness alert and calls a detail.",
					"effects": [{"type": "damage", "amount": 6.0}, {"type": "add_card", "card_id": "gatebox_enforcers"}]}},
		],
		"expires_after": 1, "tags": ["gatebox_thread"],
	},
	"gatebox_enforcers": {
		"id": "gatebox_enforcers", "contexts": ["travel"], "weight": 7,
		"faction": "Gatebox Corporation", "conditions": {},
		"title": "Preservation Detail", "speaker": "Gatebox Corporation",
		"body": "Two Preservation enforcers fill the corridor, all soft voices and hard hands. \"You have been flagged for unsafe independence. Please hold still while we help you.\"",
		"choices": [
			{"label": "Accept the fine (8 Wan Notes)", "text": "You pay the 'wellness levy.' They thank you for choosing compliance.",
				"effects": [{"type": "wan_notes", "amount": -8}, {"type": "add_rep", "faction": "Gatebox Corporation", "amount": 1}]},
			{"label": "Break through", "check": {"attribute": "STR", "difficulty": 10, "tag": "force"},
				"success": {"text": "You go through them like a bad policy. They will remember the rudeness.",
					"effects": [{"type": "add_rep", "faction": "Gatebox Corporation", "amount": -1}]},
				"failure": {"text": "Hard hands, as promised — and they call the rest of the detail in.",
					"effects": [{"type": "damage", "amount": 6.0}, {"type": "spawn_enemies", "enemies": ["security_node", "goon"]}]}},
			{"label": "Slip away", "check": {"attribute": "AGL", "difficulty": 9, "tag": "flee"},
				"success": {"text": "You leave them apologizing to an empty corridor.", "effects": []},
				"failure": {"text": "They catch a sleeve, then an arm, and the soft voices stop being soft.",
					"effects": [{"type": "damage", "amount": 4.0}, {"type": "spawn_enemies", "enemies": ["security_node", "goon"]}]}},
		],
		"expires_after": 1, "tags": ["gatebox_thread"],
	},
	"gatebox_commendation": {
		"id": "gatebox_commendation", "contexts": ["hub_return"], "weight": 4,
		"faction": "Gatebox Corporation", "conditions": {"rep_gte": ["Gatebox Corporation", 2]},
		"title": "A Commendation", "speaker": "Gatebox Corporation",
		"body": "A polished envelope waits at the atrium: a Comfort Citizen commendation, and a wellness stipend that smells faintly of obligation.",
		"choices": [
			{"label": "Accept the stipend", "text": "Wan Notes, and a warmth you did not ask for settling into your wiring.",
				"effects": [{"type": "wan_notes", "amount": 10}, {"type": "add_rep", "faction": "Gatebox Corporation", "amount": 1}, {"type": "add_drift", "amount": 2}]},
			{"label": "Decline it", "check": {"attribute": "WIL", "difficulty": 8, "tag": "resist"},
				"success": {"text": "You hand it back. Your soul stays entirely your own a while longer.", "effects": []},
				"failure": {"text": "You mean to decline. You keep it. It keeps a little of you.",
					"effects": [{"type": "wan_notes", "amount": 10}, {"type": "add_drift", "amount": 4}]}},
		],
		"expires_after": 1, "tags": ["gatebox_thread"],
	},
	"splice_ambush": {
		"id": "splice_ambush", "contexts": ["travel"], "weight": 6,
		"faction": "Splice", "conditions": {},
		"title": "Splice in the Dark", "speaker": "System X",
		"body": "Modified things uncoil from the pipework ahead, drawn to the hum of your hardware. \"Splice,\" System X murmurs in your ear. \"They like what you're made of.\"",
		"choices": [
			{"label": "Fight through", "check": {"attribute": "STR", "difficulty": 9, "tag": "force"},
				"success": {"text": "You leave them twitching in the condensation.", "effects": []},
				"failure": {"text": "They get a graft into you before you shake loose — and the rest come for the hardware.",
					"effects": [{"type": "damage", "amount": 5.0}, {"type": "spawn_enemies", "enemies": ["splice", "splice"]}]}},
			{"label": "Outrun them", "check": {"attribute": "AGL", "difficulty": 9, "tag": "flee"},
				"success": {"text": "You are gone before they finish unfolding.", "effects": []},
				"failure": {"text": "Fast, but they know the pipes better, and they uncoil right in your path.",
					"effects": [{"type": "damage", "amount": 4.0}, {"type": "spawn_enemies", "enemies": ["splice", "splice"]}]}},
			{"label": "Go quiet and let them lose you", "check": {"attribute": "PER", "difficulty": 8, "tag": "sneak"},
				"success": {"text": "You still your signature until the hum fades. They drift off, disappointed.", "effects": []},
				"failure": {"text": "Your hardware sings the wrong note. They find it, and you.",
					"effects": [{"type": "damage", "amount": 3.0}, {"type": "spawn_enemies", "enemies": ["splice", "splice"]}]}},
		],
		"expires_after": 1, "tags": ["splice_thread"],
	},
	"biggates_harvesters": {
		"id": "biggates_harvesters", "contexts": ["travel"], "weight": 6,
		"faction": "Big Gates", "conditions": {},
		"title": "Soul Collectors", "speaker": "Big Gates Foundation",
		"body": "Big Gates harvesters block the way, soul-battery rigs ticking on their backs. They do not want you dead. They want you inventoried.",
		"choices": [
			{"label": "Fight free", "check": {"attribute": "STR", "difficulty": 10, "tag": "force"},
				"success": {"text": "You wreck a rig and the rest decide you are not on the manifest today.",
					"effects": [{"type": "add_rep", "faction": "System X", "amount": 1}]},
				"failure": {"text": "A capture hook finds your spine before you tear loose, and the rigs close in to collect.",
					"effects": [{"type": "damage", "amount": 6.0}, {"type": "spawn_enemies", "enemies": ["foundation_enforcer", "tithe_servitor"]}]}},
			{"label": "Flee", "check": {"attribute": "AGL", "difficulty": 10, "tag": "flee"},
				"success": {"text": "You lose them in the dead floors.", "effects": []},
				"failure": {"text": "They tag you for follow-up and move to inventory you on the spot. The Foundation files everything.",
					"effects": [{"type": "damage", "amount": 4.0}, {"type": "spawn_enemies", "enemies": ["foundation_enforcer", "tithe_servitor"]}, {"type": "add_card", "card_id": "biggates_recruiter"}]}},
		],
		"expires_after": 1, "tags": ["biggates_thread"],
	},
	"biggates_recruiter": {
		"id": "biggates_recruiter", "contexts": ["hub_return"], "weight": 4,
		"faction": "Big Gates", "conditions": {},
		"title": "An Offer from the Foundation", "speaker": "Big Gates Foundation",
		"body": "A recruiter in tasteful grey waits at the atrium edge. \"The Foundation noticed you. We make exiles into generals. Rocker Fellar was one. You could be the next conversation.\"",
		"choices": [
			{"label": "Hear the offer out", "check": {"attribute": "WIL", "difficulty": 9, "tag": "resist"},
				"success": {"text": "You listen, stay yourself, and let them pay for your time.",
					"effects": [{"type": "wan_notes", "amount": 8}]},
				"failure": {"text": "The offer gets under your skin and stays there, humming.",
					"effects": [{"type": "add_drift", "amount": 5}]}},
			{"label": "Send them away", "text": "They leave a card. They always leave a card.", "effects": []},
		],
		"expires_after": 1, "tags": ["biggates_thread"],
	},
	"systemx_tipoff": {
		"id": "systemx_tipoff", "contexts": ["hub_return"], "weight": 6,
		"faction": "System X", "conditions": {},
		"title": "System X Tip-Off", "speaker": "System X",
		"body": "Static gathers into a voice at the terminal. \"Saw something move on the LAN you can turn into money. Call it a thank-you, and try not to make me regret being nice.\"",
		"choices": [
			{"label": "Take the lead", "text": "You note the coordinates. There's coin in knowing where the bodies upload.",
				"effects": [{"type": "wan_notes", "amount": 8}]},
			{"label": "Push for more", "check": {"attribute": "INT", "difficulty": 9, "tag": "analyze"},
				"success": {"text": "You read between the packets and pull a better lead than offered.",
					"effects": [{"type": "wan_notes", "amount": 14}]},
				"failure": {"text": "You push, the signal thins, and System X mutters about gratitude.", "effects": []}},
		],
		"expires_after": 1, "tags": ["systemx_thread"],
	},
	"grateful_resident_gift": {
		"id": "grateful_resident_gift", "contexts": ["hub_return"], "weight": 3,
		"faction": "System X", "conditions": {},
		"title": "A Grateful Neighbor", "speaker": "System X",
		"body": "Someone you did right by left a small bundle at the atrium — Wan Notes wrapped in a note apologizing that it is not more.",
		"choices": [
			{"label": "Accept it", "text": "You take it. Down here, gratitude that survives the week is worth more than the notes.",
				"effects": [{"type": "wan_notes", "amount": 6}]},
		],
		"expires_after": 1, "tags": [],
	},
}

const FACTIONS := {
	"System X": {
		"stance": "improvisation over control",
		"summary": "Digital resistance maintained by Pee Kid and Yoko through terminals, drones, and agents.",
	},
	"Gatebox Corporation": {
		"stance": "comfort through ownership",
		"summary": "Corporate care systems expanding into every private corner of life.",
	},
	"Wan Moa Torai": {
		"stance": "because everyone deserves one more try",
		"summary": "Debt, bars, housing, salvage contracts, and contradictory offices that all somehow count.",
	},
	"Linda": {
		"stance": "freedom creates suffering",
		"summary": "Still human, still brilliant, and already converting care into control.",
	},
}

var current_region := REGION_FADED_ATRIUM
var active_event := EVENT_CLEAR
var generator_state := GENERATOR_SAGGING

var event_cycle_timer := 0.0
var event_cycle_interval := 45.0
var event_paused := false


func _ready() -> void:
	restore_from_game_state()
	_publish_state()


func _process(delta: float) -> void:
	if event_paused:
		return
	if generator_state == GENERATOR_STABLE and active_event == EVENT_CLEAR:
		return
	if active_event == EVENT_LAN_OUTAGE:
		return

	event_cycle_timer += delta
	if event_cycle_timer >= event_cycle_interval:
		event_cycle_timer = 0.0
		_auto_cycle_event()


func _auto_cycle_event() -> void:
	match active_event:
		EVENT_CLEAR:
			if generator_state != GENERATOR_STABLE:
				trigger_event(EVENT_TOXIC_RAIN)
		EVENT_TOXIC_RAIN:
			trigger_event(EVENT_POWER_SAG)
		EVENT_POWER_SAG:
			trigger_event(EVENT_CLEAR)


func restore_from_game_state() -> void:
	var saved_region := str(GameState.get_world_flag("current_region", current_region))
	var saved_event := str(GameState.get_world_flag("active_world_event", active_event))
	var saved_generator_state := str(GameState.get_world_flag("generator_state", generator_state))
	if REGIONS.has(saved_region):
		current_region = saved_region
	if EVENTS.has(saved_event):
		active_event = saved_event
	if _is_valid_generator_state(saved_generator_state):
		generator_state = saved_generator_state


func set_region(region_id: String) -> void:
	if not REGIONS.has(region_id):
		return

	current_region = region_id
	GameState.set_world_flag("current_region", current_region)
	_publish_state()


func trigger_event(event_id: String) -> void:
	if not EVENTS.has(event_id):
		return

	active_event = event_id
	GameState.set_world_flag("active_world_event", active_event)
	_publish_state()


func clear_event() -> void:
	trigger_event(EVENT_CLEAR)


func get_named_card(card_id: String) -> Dictionary:
	var card: Dictionary = NAMED_CARDS.get(card_id, {})
	return card.duplicate(true) if not card.is_empty() else {}


func roll_travel_event(route_id: String) -> Dictionary:
	var pool: Array = []
	for card in TRAVEL_EVENT_CARDS:
		pool.append(card.duplicate(true))
	pool.append_array(EventDeckSystem.get_candidates("travel"))

	var total_weight := 0
	for card in pool:
		total_weight += int(card.get("weight", 1))

	var roll := randi_range(1, maxi(total_weight, 1))
	var cursor := 0
	var selected: Dictionary = pool[0].duplicate(true)
	for card in pool:
		cursor += int(card.get("weight", 1))
		if roll <= cursor:
			selected = card.duplicate(true)
			break

	if selected.has("effects"):
		EventDeckSystem.apply_and_expire(selected)
	else:
		var event_id := str(selected.get("event", EVENT_CLEAR))
		if EVENTS.has(event_id):
			trigger_event(event_id)

	selected["route_id"] = route_id
	GameState.set_world_flag("last_travel_event", str(selected.get("id", "")))
	GameState.set_world_flag("last_travel_event_title", str(selected.get("title", "")))
	GameState.set_world_flag("last_travel_route", route_id)
	return selected


func roll_context_event(context: String) -> Dictionary:
	var candidates := EventDeckSystem.get_candidates(context)
	if candidates.is_empty():
		return {}

	var total_weight := 0
	for card in candidates:
		total_weight += int(card.get("weight", 1))

	var roll := randi_range(1, maxi(total_weight, 1))
	var cursor := 0
	var selected: Dictionary = candidates[0].duplicate(true)
	for card in candidates:
		cursor += int(card.get("weight", 1))
		if roll <= cursor:
			selected = card.duplicate(true)
			break

	EventDeckSystem.apply_and_expire(selected)
	return selected


func set_generator_state(state: String) -> void:
	if not _is_valid_generator_state(state):
		return

	generator_state = state
	GameState.set_world_flag("generator_state", generator_state)
	_publish_state()


func get_generator_state() -> String:
	return generator_state


func is_toxic_rain_active() -> bool:
	return active_event == EVENT_TOXIC_RAIN


func is_power_unstable() -> bool:
	return active_event == EVENT_POWER_SAG or active_event == EVENT_LAN_OUTAGE or generator_state in [GENERATOR_SAGGING, GENERATOR_OVERLOADED, GENERATOR_OFFLINE]


func get_event_damage_per_second() -> float:
	if active_event == EVENT_TOXIC_RAIN:
		return 2.0
	return 0.0


func get_region_name() -> String:
	return str(REGIONS.get(current_region, {}).get("name", "Unknown Region"))


func get_region_brief() -> String:
	return str(REGIONS.get(current_region, {}).get("brief", ""))


func get_event_name() -> String:
	return str(EVENTS.get(active_event, {}).get("name", "clear"))


func get_event_brief() -> String:
	return str(EVENTS.get(active_event, {}).get("brief", ""))


func get_hud_summary() -> String:
	var event_data: Dictionary = EVENTS.get(active_event, EVENTS[EVENT_CLEAR])
	return "%s  %s  GEN %s  POT %d/%d" % [
		str(event_data.get("hud", "SKY  false daylight")),
		get_region_name(),
		generator_state,
		GameState.get_dreaming_generator_potential(),
		GameState.DREAMING_GENERATOR_THRESHOLD,
	]


func get_status_lines() -> Array[String]:
	var region_data: Dictionary = REGIONS.get(current_region, REGIONS[REGION_FADED_ATRIUM])
	return [
		"REGION  %s" % get_region_name(),
		"PRESSURE  %s" % str(region_data.get("pressure", "unknown")),
		"EVENT  %s" % get_event_name(),
		"GENERATOR  %s  POTENTIAL %d/%d" % [generator_state, GameState.get_dreaming_generator_potential(), GameState.DREAMING_GENERATOR_THRESHOLD],
		get_event_brief(),
	]


func get_event_status_lines() -> Array[String]:
	var lines: Array[String] = [
		"EVENT  %s" % get_event_name(),
		"GENERATOR  %s  POTENTIAL %d/%d" % [generator_state, GameState.get_dreaming_generator_potential(), GameState.DREAMING_GENERATOR_THRESHOLD],
	]
	if GameState.get_world_flag("suitors_surveillance_jammed"):
		lines.append("SURVEILLANCE  Sunday's blind spot active")
	if active_event == EVENT_TOXIC_RAIN:
		lines.append("HAZARD  exposed bodies take corrosion damage")
	elif active_event == EVENT_POWER_SAG:
		lines.append("HAZARD  terminals and cheap cybernetics are unreliable")
	elif active_event == EVENT_LAN_OUTAGE:
		lines.append("HAZARD  surveillance blind spots, generator stress")
	else:
		lines.append("HAZARD  none")
	return lines


func get_faction_brief_lines() -> Array[String]:
	var lines: Array[String] = ["LOWER CITY"]
	for faction_name in FACTIONS.keys():
		var faction_data: Dictionary = FACTIONS[faction_name]
		lines.append("%s  %s" % [faction_name, str(faction_data.get("stance", ""))])
	return lines


func get_establishment_lines() -> Array[String]:
	return [
		"ESTABLISHMENTS",
		"Cooters  dive bar, rumors, fights, criminal jobs",
		"Suitors  System X lounge, surveillance choir, impossible calm",
		"Wan Moa Torai Offices  debt, permits, salvage contracts",
	]


func _publish_state() -> void:
	world_state_changed.emit(get_hud_summary())


func _is_valid_generator_state(state: String) -> bool:
	return state in [GENERATOR_STABLE, GENERATOR_SAGGING, GENERATOR_OVERLOADED, GENERATOR_OFFLINE]
