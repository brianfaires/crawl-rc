---------------------------------------------------------------------------------------------------
-- BRC feature module: mute-messages
-- @module f_mute_messages
-- Mutes various crawl messages, with configurable levels of reduction.

f_mute_messages = {}
f_mute_messages.BRC_FEATURE_NAME = "mute-messages"
f_mute_messages.Config = {
  do_exploration_mutes = true, -- Mute boring messages while auto-exploring
  mute_level = 2,
  messages = {
    -- Only mute these when auto-exploring
    explore_only = {
      "There is a.*(staircase|door|gate|hatch).*here",
      "You enter the shallow water",
      "Moving in this stuff is going to be slow",
      "You see here .*(corpse|skeleton)",
      "You.*open the door",
      "You disentangle yourself",
      "You see here .*",
    },

    -- Light reduction; unnecessary messages
    [1] = {
      -- Unnecessary
      "You now have .* runes",
      "to see all the runes you have collected",
      "A chill wind blows around you",
      "An electric hum fills the air",
      "You reach to attack",

      -- Interface
      "for a list of commands and other information",
      "Marking area around",
      "(Reduced|Removed|Placed new) exclusion",
      "You can access your shopping list by pressing '\\$'",

      -- Wielding weapons
      "Your .* begins to drip with poison",
      "Your .* stops dripping with poison",
      "Your .* bursts into flame",
      "Your .* quivers in your",
      "Your .* stops (flaming|quivering)",
      "Your .* glows with a cold blue light",
      "Your .* stops glowing",
      "You hear the crackle of electricity",
      "Your .* stops crackling",
      "Your .* exudes an aura of protection",
      "Your .* hums with potential",
      "Your .* goes still",
      "You sense an unholy aura",

      -- Monsters /Allies / Neutrals
      "dissolves into shadows",
      "You swap places",
      "Your spectral weapon disappears",

      -- Spells
      "Your foxfire dissipates",

      -- Religion
      "accepts your kill",
      "is honoured by your kill",
    },

    -- Moderate reduction; potentially confusing but no info lost
    [2] = {
      -- Allies / monsters
      "Ancestor HP restored",
      "The (bush|fungus|plant) (looks sick|begins to die|is engulfed|is struck)",
      "evades? a web",
      "is (lightly|moderately|heavily|severely) (damaged|wounded)",
      "is almost (dead|destroyed)",

      -- Interface
      "Use which ability\\?",
      "Evoke which item\\?$",
      "Shift\\-Dir \\- straight line",

      -- Books
      "You pick up (?!a manual).*and begin reading",
      "Unfortunately\\, you learn nothing new",

      -- Ground items / features
      "There is a.*(door|web).*here",
      "You see here .*(corpse|skeleton)",
      "You now have \\d+ gold piece",
      "You enter the shallow water",
      "Moving in this stuff is going to be slow",

      -- Religion
      "Your shadow attacks",
    },

    -- Heavily reduced messages for realtime speedruns
    [3] = {
      "No target in view",
      "You (bite|headbutt|kick)",
      "You (burn|freeze|drain)",
      "You block",
      "but do(es)? no damage",
      "misses you",
    },
  },
} -- f_mute_messages.Config (do not remove this comment)

---- Macro functions ----
function macro_brc_muted_explore()
  if BRC.active and
    not f_mute_messages.Config.disabled and
    f_mute_messages.Config.do_exploration_mutes
  then
    for _, message in ipairs(f_mute_messages.Config.messages.explore_only) do
      BRC.opt.single_turn_mute(message)
    end
  end

  BRC.util.do_cmd("CMD_EXPLORE")
end

---- Initialization ----
function f_mute_messages.init()
  if f_mute_messages.Config.do_exploration_mutes then
    BRC.opt.macro(BRC.util.get_cmd_key("CMD_EXPLORE") or "o", "macro_brc_muted_explore")
  end

  if f_mute_messages.Config.mute_level and f_mute_messages.Config.mute_level > 0 then
    for i = 1, f_mute_messages.Config.mute_level do
      if not f_mute_messages.Config.messages[i] then break end
      for _, message in ipairs(f_mute_messages.Config.messages[i]) do
        BRC.opt.message_mute(message, true)
      end
    end
  end
end
