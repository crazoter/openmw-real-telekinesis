# Real Telekinesis
A mod for OpenMW that allows you to perform *real* telekinesis on NPCs, creatures and objects.

### Main Features
1. Interact with objects and living creatures by telekinetically pushing, pulling, lifting, and grabbing them
2. You can actually hurt creatures by smacking them with objects, or vice-versa, and they experience gravity if you throw them
3. "Jedi Academy" camera option so that you can throw creatures around without experiencing (too much) motion sickness
4. Tiers of telekinetic powers based on how long you hold the attack; the longer the more powerful

### Requirements
OpenMW 0.48+. Install like any other OpenMW mod: linking adding the directory of the files of this mod to the data directories list. Note that this is almost entirely written in OpenMW lua, so it (very likely) won't work with multiplayer mode.

### State of Mod
Complete and updates are unlikely, except for urgent bug-fixes or whatever I feel like.

### Transcript
1
This is a mod for Open Source Morrowind, and it aims to grant players real, actual telekinetic powers. You may be familiar with the game's telekinesis spell under the mysticism family, and how it works; it allows you to interact with objects further away from you and pick up items from a distance. All this does is allow you to teleport items into your inventory. There's nothing telekinetic about that at all. Real telekinesis allows you to push, pull, grab, and basically apply force to objects at a distance using some sort of magical power. And that, is what this mod allows you to do. 

I was inspired to make this because I played Starwind, a total conversion mod that takes Morrowind and changes it into a completely different game, based on Star Wars. A huge part of what makes a Jedi or a Sith iconic is their force powers. Force push, force pull, force choke etcetera all allow force sensitives to manipulate objects or even their adversaries from a distance, and I wanted to make it a reality with this mod. This video will showcase a good portion of what this mod has to offer, and I hope that the mod will enhance your Morrowind experience as much as it has enhanced mine. Let's get to it.

2
Let's first run through the basics. This mod enables you to use four types of telekinetic powers on objects and living beings, Telekinetic push, Telekinetic pull, Telekinetic lift, And last but not least, Telekinetic grab. 

Each of these powers can be activated by moving your crosshair onto a suitable target, and pressing the respective keyboard key to activate them. Pushing, pulling and lifting all begin to charge the ability when you press their button, and activates when you release their button. You can grab and release targets by pressing the grab key to toggle the ability. These key mappings can be changed in the settings. There are also many other configurable settings exposed to the player, but for simplicity sake, it is best to only modify the basic settings.

This mod implements a basic collision and physics system that will hurt living creatures as they hit objects around them, so not only can you use your telekinetic powers as a quality of life tool to move characters out of the way, you can actually use these powers to hurt people, like a real Sith Lord.

The magicka cost scales with your Mysticism skill; the higher your Mysticism skill, the lower the cost required to use these abilities. 
Because these abilities are incredibly powerful, you can only use them on creatures that are at the same level or lower than you, and the game will inform you about that restriction. 

As a quality of life, this mod also implements a new camera system based on the Jedi Knight Jedi Academy game that should reduce motion sickness when throwing creatures around with your force powers. It is optional and you can toggle it using a keyboard key.

3
Next, let's talk about some of the more advanced features available to the player. You can actually pick up items and weapons, and you will automatically begin to spin them, and the amount of damage you deal with these things depend on your mysticism skill and the slash damage of the item you are controlling. While grabbing an object, press the push or pull key to extend them further away or closer to you. This allows you to do incredibly cool things like telekinetic lightsaber attacks, or incredibly silly things like attacking enemies with a fork. Unfortunately open morrowind doesn't allow us to actually throw objects yet, so we have to first drop them to begin manipulating them.

4
You might be wondering, since this mod was inspired by Star Wars, is there Darth Vader signature force choke move? The answer is yes, although in the form of force whirlwind, because I'm lazy and all I can do to make the creature look like it is getting badly hurt is to spin it round and round like a record. To do this, simply hold both the push and pull keys together while you are grabbing your target. Be warned however that it causes you to use more magicka as you do this.

5
You may also be curious about the different tiers of powers when you push, pull or lift a target. The first tier is a single target ability that only affects the target your crosshair is on. The second tier, which is activated if you hold the attack long enough, affects targets in front of you in a conical shape. The third tier affects targets in all directions around you. The fourth tier is a more powerful variant of the third tier, and I'll let you explore the effects of these special attacks on your own. All of these area of effect abilities can affect enemies through walls, and the range of these abilities is affected by your Mysticism level. The higher your Mysticism level, the further away you can affect targets. Note that these abilities will also hurt friendly targets, so be wary of your surroundings if you're using the third and fourth tiers. Note that these telekinetic effects will bypass spell reflect and absorption because of technical limitations.

6
Finally, you may notice that even though you are breaking all kinds of laws by using these telekinetic powers, NPCs don't react to it. This is due to technical limitations, but at the same time, realistically speaking, if someone was to manipulate an object from afar, there is no way you're going to figure out who is the one doing it, especially if they are not holding their hand out. So use these powers responsibly, because with great power comes great responsbility. Unless you are evil, then just feel free to go ham and send these poor souls straight to heaven.

Thank you for watching. If you liked this video please sub, nah I am just kidding I don't really care about that. I hope you enjoy the mod and if you have any feedback just hit me up on Discord or something. If you enjoyed the narration of this video, you might be pleased to know that I enjoyed it too. I made it using Adachi Tohrus voice via Deep Ponies Text To Speech. Have a great day.

### Other tips & tricks
- Level restrictions: You will consume magicka even if the target resists your attack. Use a weaker power like grab to test your opponent first.
- Combos: While there is a creature / object currently affected by your telekinesis, push, pull, or lift powers can be used at half cost. Players are encouraged to chain force powers together to manage their magicka usage.

### Description of Force Powers
#### Push
- Telekinetic Push (Single Target) (Cast time: 0.2s, Base cost: 30): Telekinetic push at a single target that the player's crosshair is on. Knocks target down.
- Wide Telekinetic Push (Cone AOE) (Cast time: 1.5s, Base cost: 70): Telekinetic push in a conical shape coming from the player. Knocks targets down.
- Telekinetic Wave (Centred AOE) (Cast time: 2s, Base cost: 100): Telekinetic push in all directions, centred at the player's position. Knocks targets down.
- Telekinetic Explosion (Pinpoint AOE) (Cast time: 1.5s, Base cost: 110): A telekinetic wave, but the origin of this explosion is now at a fixed distance from the player. The player can somewhat control the origin of this explosion using their crosshair. The 4th tier of push is also the hardest to use, hence it has the lowest cast time and base cost of all 3 force powers.

#### Pull
- Telekinetic Pull (Single Target) (Cast time: 0.2s, Base cost: 20): Telekinetic pull at a single target that the player's crosshair is on.
- Wide Telekinetic Pull (Cone AOE) (Cast time: 1.5s, Base cost: 50): Telekinetic pull in a conical shape coming from the player. Knocks targets down.
- Telekinetic Vortex (Centred AOE) (Cast time: 2s, Base cost: 80): Telekinetic pull in all directions, centred at the player's position. Knocks targets down.
- Telekinetic Black Hole (Pinpoint AOE) (Cast time: 4s, Base cost: 300): Summons a slower but longer lasting telekinetic vortex. The origin of this vortex is now at a fixed distance from the player. The player can somewhat control the origin of this vortex using their crosshair at the time of casting. Telekinetic black hole is very powerful (and broken) ability when used correctly, hence the high cost and casting time.

#### Lift
- Telekinetic Lift (Single Target) (Cast time: 0.2s, Base cost: 20): Telekinetic lift at a single target that the player's crosshair is on.
- Wide Telekinetic Lift (Cone AOE) (Cast time: 1.5s, Base cost: 70): Telekinetic lift in a conical shape coming from the player.
- Telekinetic Earthshatter (Centred AOE) (Cast time: 1.5s, Base cost: 100): Telekinetic lift in all directions, centred at the player's position. Knocks targets down.
- Telekinetic Eruption (Centred AOE) (Cast time: 2s, Base cost: 140): Telekinetic earthshatter but stronger.

#### Grab
- Grab NPC / Creature: 70/s cost
- Whirlwind NPC / Creature: Extra 20/s cost
- Grab item: 30/s cost

### Potential improvements that I won't work on because they are too much work but others may want to:
- [ ] Navigating through a cell while grabbing something will bring them to the new cell instead of glitching out
- [ ] Enemies can also use these telekinetic abilities (on you)
- [ ] Bounding box calculations also apply to dead enemies, so that objects will go over their corposes instead of bumping into them like they are still standing
- [ ] Further Performance optimization for the Telekinetic Black Hole ability

### Known issues:
- [ ] Object may sometimes clip through walls
	- [ ] The collision may, very rarely, bug out and your object may go out of bounds. But I believe it should be somewhat unlikely unless you intentionally try to force an object through the wall or that area has some weird walls; most of the time if something / someone disappeared it's because you flung them too far lol. The collision system is pretty difficult to get perfect, so I'm satisfied with how it performs now considering that a good portion of the development work went into extending the collision system provided by the lua API
	- [ ] As for items, items by default don't have collision detection. So if they are placed on shelves for example, picking them up will cause issues. Fixing this means that items must be able to clip through arbitrary objects, which is not easy to specify.
- [ ] Make enemy animate "fall down" only after getting hit
	- [ ] Won't fix: The same code can have inconsistent behavior depending on where it is called (onUpdate / onKeyPress). In this case putting it in onUpdate causes weird issues. Potentially easy to fix w/ investigation, but didn't really feel impactful to make this change so I left it as-is
- [ ] Items' bounding box is not accurate
	- [ ] Can't fix: This is probably only obvious if manipulating bigger objects or really small objects. Items don't have a bounding box, so it's hardcoded to a constant size.
- [ ] Gravity still applies while in water
	- [ ] Won't fix: isSwimming detection does not work properly for Manaan, COLLISION_TYPE.Water doesn't work either. No way to reliably determine if object is in water; GetWaterLevel is in mwscript and interfacing it with OpenMW Lua is too much of a hassle.
- [ ] No sound
	- [ ] Won't fix: Because it is difficult to make my lua scripts somehow communicate to a mwscript to make it play a specific sound at a specific location, and then clean up said item after the sound is played. That's like 4 different problems just to generate a "boop" SFX. Just make the sounds with your mouth bro lol
- [ ] Using these telekinetic powers don't increase any skills
	- [ ] Can't fix: This is currently not possible because the thing we need to modify is read-only.
- [ ] Hitting something with an item doesn't reduce its durability or trigger it's on-hit effects
	- [ ] Can't fix: this functionality is not available on openmw lua
- [ ] Bullets fired in "Jedi Academy Camera" mode may not perfectly aligned vertically
	- [ ] Won't fix: Because the z position of the camera is different from the z position of the gun, it's not possible to align them perfectly. You can tweak this by modifying the CONVERGENCE_FACTOR value (e.g. to 0.05), but doing so will mean that it will be harder for you to use items in that camera mode, so it's a trade-off.
- [ ] Cannot throw lightsaber / weapons and then re-equip it after grabbing it again
	- [ ] Can't fix: OpenMW lua has no such functionality
- [ ] Interacting with the keys while the game is paused may caused unintended effects
	- [ ] Won't fix: lazy

### Credits:
- This mod uses a custom crosshair from https://infestationnewz.fandom.com/wiki/Custom_Crosshair

### Extension:
-  Feel free to modify / extend the mod for your own purposes, but please credit if a significant portion of the code is used.