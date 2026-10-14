/* ================= CONTENT DATA (all balance lives here) ================= */
const RAR=[['COMMON','#9aa0ab',.55,1],['UNCOMMON','#5be37d',.25,1.2],['RARE','#4aa3ff',.12,1.4],['EPIC','#b44cff',.055,1.6],['LEGENDARY','#ffb23f',.02,2],['MYTHIC','#ff3d7f',.005,2.5]];
// Weapons: base stats + 7 level deltas (LV 1 -> 8). cd deltas are multipliers. Evolution: max level + listed tome.
const WEAP={
 volley:{name:'Feather Volley',icon:'feather_volley',desc:'Fires feathers at the nearest enemy.',base:{dmg:14,cd:.75,n:1,pierce:1,spd:12},
   lv:[{n:1},{dmg:5},{cd:-.12},{pierce:1},{n:1},{dmg:6},{n:1}], evo:{tome:'cooldown',name:'Plume Tempest',desc:'A spinning storm of feathers that pierce everything.'}},
 pop:{name:'Kernel Pop',icon:'kernel_pop',desc:'Popcorn bursts around you.',base:{dmg:9,cd:1.5,r:1.9},
   lv:[{r:.3},{dmg:4},{cd:-.12},{r:.3},{dmg:5},{cd:-.12},{dmg:8,r:.4}], evo:{tome:'regen',name:'Butter Nova',desc:'Huge bursts that heal you on hit.'}},
 gull:{name:'Gull Dive',icon:'gull_dive',desc:'Gulls dive-bomb random enemies.',base:{dmg:32,cd:2.4,n:1,r:1.4},
   lv:[{n:1},{dmg:12},{r:.3},{cd:-.15},{n:1},{dmg:16},{n:2}], evo:{tome:'duration',name:'Gull Storm',desc:'A never-ending rain of gulls.'}},
 seed:{name:'Seed Spitter',icon:'seed_spitter',desc:'Seeds bounce between enemies.',base:{dmg:8,cd:1,n:1,bounce:2,spd:11},
   lv:[{bounce:1},{dmg:3},{n:1},{bounce:2},{cd:-.15},{dmg:4},{n:1}], evo:{tome:'amount',name:'Sunflower Barrage',desc:'Seeds burst in every direction and bounce forever.'}},
 parrot:{name:'Parrot Strike',icon:'parrot',desc:'Parrots circle you and peck what they touch.',base:{dmg:8,cd:.45,n:1,r:1.7,spin:2.6},
   lv:[{n:1},{dmg:4},{r:.3},{spin:.8},{n:1},{dmg:6},{n:1}], evo:{tome:'area',name:'Macaw Cyclone',desc:'The orbit pulses wide and fast.'}},
 crowpick:{name:'Crow Pick',icon:'pickaxe',desc:'A heavy swing in front of you. Big knockback.',base:{dmg:24,cd:1.25,r:2.1,arc:2.1},
   lv:[{dmg:8},{r:.4},{cd:-.1},{arc:.6},{dmg:10},{r:.4},{dmg:14}], evo:{tome:'might',name:'Raven Reaper',desc:'Full-circle swings that finish weak enemies.'}},
 chain:{name:'Storm Chain',icon:'storm_locket',desc:'Lightning jumps between enemies.',base:{dmg:15,cd:1.7,chains:3},
   lv:[{chains:1},{dmg:5},{cd:-.12},{chains:2},{dmg:7},{cd:-.12},{chains:3}], evo:{tome:'luck',name:'Thunder Locket',desc:'Strikes twice and never weakens.'}},
 egg:{name:'Egg Bomb',icon:'nest',desc:'Lobs eggs that explode on landing.',base:{dmg:28,cd:2.1,n:1,r:1.6},
   lv:[{r:.3},{dmg:10},{n:1},{cd:-.12},{r:.4},{dmg:14},{n:1}], evo:{tome:'projspeed',name:'Golden Omelette',desc:'Eggs leave burning pools behind.'}},
 nest:{name:'Nest Guard',icon:'shield',desc:'Twig shields circle you and shove enemies.',base:{dmg:6,cd:.5,n:2,r:1.25,spin:3.4},
   lv:[{n:1},{dmg:3},{r:.2},{n:1},{dmg:4},{spin:1},{n:1}], evo:{tome:'armor',name:'Fortress Nest',desc:'Six shields that also block enemy shots.'}},
 tornado:{name:'Plume Tornado',icon:'wing',desc:'A tornado wanders through the horde.',base:{dmg:7,cd:4,n:1,r:1.3,dur:3.5},
   lv:[{dur:1},{dmg:3},{r:.3},{n:1},{dur:1.5},{dmg:4},{n:1}], evo:{tome:'speed',name:'Plume Hurricane',desc:'Tornados follow you and pull in gems.'}},
};
// Tomes: 5 levels each. Each card applies one level, scaled by the card's rarity.
const TOME={
 might:{name:'Might Tome',icon:'sword',desc:'+10% damage',f:(S,k)=>S.might+=.10*k},
 area:{name:'Area Tome',icon:'aura',desc:'+10% area',f:(S,k)=>S.area+=.10*k},
 cooldown:{name:'Cooldown Tome',icon:'clock',desc:'-7% cooldown',f:(S,k)=>S.cooldown*=1-.07*k},
 amount:{name:'Amount Tome',icon:'plume',desc:'+1 projectile every 2 levels',f:(S,k,l)=>{ if(l%2===0) S.amount+=1; S.might+=.02*k; }},
 duration:{name:'Duration Tome',icon:'teleport',desc:'+15% effect duration',f:(S,k)=>S.duration+=.15*k},
 projspeed:{name:'Velocity Tome',icon:'feather_volley',desc:'+15% projectile speed',f:(S,k)=>S.proj+=.15*k},
 speed:{name:'Agility Tome',icon:'hunter_momentum',desc:'+8% move speed',f:(S,k)=>S.speed*=1+.08*k},
 maxhp:{name:'Vitality Tome',icon:'heart',desc:'+20 max HP',f:(S,k)=>{S.maxhp+=20*k;}},
 regen:{name:'Regen Tome',icon:'mushroom',desc:'+0.3 HP per second',f:(S,k)=>S.regen+=.3*k},
 armor:{name:'Armor Tome',icon:'shield',desc:'+12% armor',f:(S,k)=>S.armor+=.12*k},
 magnet:{name:'Magnet Tome',icon:'magnet',desc:'+40% pickup range',f:(S,k)=>S.magnet*=1+.4*k},
 luck:{name:'Luck Tome',icon:'golden',desc:'+10% luck (rarer cards)',f:(S,k)=>S.luck+=.10*k},
 growth:{name:'Growth Tome',icon:'ore',desc:'+10% XP',f:(S,k)=>S.growth+=.10*k},
 greed:{name:'Greed Tome',icon:'moneta',desc:'+20% gold',f:(S,k)=>S.greed+=.20*k},
 crit:{name:'Crit Tome',icon:'crown',desc:'+6% crit chance',f:(S,k)=>S.crit+=.06*k},
};
// Items (Birb artifacts) from gold chests. Stack; value scales with the chest rarity.
const ITEM={
 blood_beak:{name:'Blood Beak',icon:'blood_beak',desc:k=>`Heal ${(1.5*k).toFixed(1)}% of damage dealt`},
 storm_locket:{name:'Storm Locket',icon:'storm_locket',desc:k=>`Every 6th hit chains to 2 enemies for ${Math.round(60*k)}%`},
 point_hoard:{name:'Point Hoard',icon:'point_hoard',desc:k=>`+${Math.round(15*k)}% XP and gold`},
 hunter_momentum:{name:'Hunter Momentum',icon:'hunter_momentum',desc:k=>`Kills give +${Math.round(15*k)}% speed for 3s`},
 splitter_haste:{name:'Splitter Haste',icon:'splitter_haste',desc:k=>`Every 5th hit: ${Math.round(25*k)}% faster weapons for 3s`},
 opening_strike:{name:'Opening Strike',icon:'sword',desc:k=>`+${Math.round(80*k)}% damage to full-HP enemies`},
 focused_assault:{name:'Focused Assault',icon:'trophy',desc:k=>`Up to +${Math.round(30*k)}% damage while not hit`},
 redline:{name:'Redline',icon:'heart',desc:k=>`+${Math.round(40*k)}% damage below 40% HP`},
 iron_feather:{name:'Iron Feather',icon:'shield',desc:k=>`+${Math.round(10*k)}% armor`},
 golden_kernel:{name:'Golden Kernel',icon:'popcorn',desc:k=>`+${Math.round(30*k)}% gold`},
 clover:{name:'Lucky Clover',icon:'golden',desc:k=>`+${Math.round(15*k)}% luck`},
 echo_wing:{name:'Echo Wing',icon:'wing',desc:()=>'+1 projectile for every weapon'},
 phoenix:{name:'Phoenix Plume',icon:'plume',desc:()=>'Revive once at 50% HP'},
 molten:{name:'Molten Core',icon:'ore',desc:k=>`Hits burn for ${Math.round(4*k)} damage per second`},
 skull:{name:'Cursed Skull',icon:'monster',desc:k=>`+${Math.round(25*k)}% enemies, +${Math.round(25*k)}% XP and gold`},
};
// Enemies: hp, speed, damage, size, xp, behaviour, tier (swarm/basic/special/brute), flies (ignores terrain)
const ENEMY={
 twig_blight:[14,1.9,6,30,1,'chase','basic'], giant_fly:[8,2.9,4,28,1,'chase','swarm',1], slime_sprout:[20,1.4,6,28,1,'split','basic'], flower_monster:[24,1.1,8,32,2,'ranged','special'],
 shadow_wolf:[30,3.1,10,36,3,'charge','special'], mushroom_brute:[90,1.0,15,44,5,'chase','brute'], bee_swarm:[6,3.4,3,22,1,'chase','swarm',1],
 ghost:[16,2.1,7,32,1,'chase','basic',1], skeleton:[24,1.8,8,32,2,'chase','basic'], witch:[34,1.9,10,36,3,'ranged','special',1],
 mummy:[40,1.3,10,34,2,'chase','brute'], cobra:[18,2.6,9,30,2,'charge','special'], anubis:[110,1.6,15,46,6,'ranged','brute'],
 frost_wisp:[14,2.6,7,30,1,'chase','swarm',1], frozy_cube:[60,1.1,12,38,4,'split','brute'], ice_harpy:[28,3,10,36,3,'charge','special',1],
 fishfolk:[28,1.9,9,34,2,'ranged','basic'], crab:[40,1.4,10,32,2,'charge','special'], sea_horror:[120,1.2,16,48,7,'ranged','brute'],
 imp:[20,2.8,10,30,2,'chase','basic'], hell_critter:[32,3,12,34,3,'charge','special'], cacodaemon:[120,1.4,18,48,7,'ranged','brute',1],
 elite_twig_blight:[200,1.6,16,46,15,'chase','elite'], bramble_golem:[900,1.15,26,84,60,'boss','mini'], hornet_queen:[800,2,22,76,60,'boss','mini',1],
 treant_elder:[3200,1.05,32,110,200,'boss','boss'], archivist:[3800,1.25,34,104,250,'boss','boss',1],
};
const BIOME_ROLE=[ // swarm/basic/special/brute pools, elite, miniboss, final boss per biome
 {swarm:['giant_fly','bee_swarm'],basic:['twig_blight','slime_sprout'],special:['flower_monster','shadow_wolf'],brute:['mushroom_brute'],elite:'elite_twig_blight',mini:'bramble_golem',boss:'treant_elder'},
 {swarm:['ghost','giant_fly'],basic:['skeleton','ghost'],special:['witch','shadow_wolf'],brute:['mushroom_brute'],elite:'witch',mini:'hornet_queen',boss:'archivist'},
 {swarm:['bee_swarm'],basic:['mummy','cobra'],special:['cobra','flower_monster'],brute:['anubis'],elite:'anubis',mini:'bramble_golem',boss:'treant_elder'},
 {swarm:['frost_wisp'],basic:['frost_wisp','slime_sprout'],special:['ice_harpy'],brute:['frozy_cube'],elite:'frozy_cube',mini:'hornet_queen',boss:'treant_elder'},
 {swarm:['giant_fly'],basic:['fishfolk','crab'],special:['crab','fishfolk'],brute:['sea_horror'],elite:'sea_horror',mini:'bramble_golem',boss:'archivist'},
 {swarm:['imp'],basic:['imp','hell_critter'],special:['hell_critter'],brute:['cacodaemon'],elite:'cacodaemon',mini:'hornet_queen',boss:'archivist'},
];
// The 30-minute timeline (story minutes; Quick runs compress it to 10 real minutes)
const TIMELINE=[
 {m:1.5,t:'swarm'},{m:3,t:'elite'},{m:4,t:'ring'},{m:5.5,t:'rush'},{m:6,t:'elite'},{m:7.5,t:'swarm'},{m:9,t:'elite'},
 {m:10,t:'mini'},{m:11.5,t:'ring'},{m:12.5,t:'swarm'},{m:13,t:'elite'},{m:14,t:'rush'},{m:15,t:'bloodmoon'},{m:16,t:'elite'},{m:17.5,t:'ring'},{m:18.5,t:'swarm'},{m:19,t:'elite'},
 {m:20,t:'mini'},{m:21.5,t:'rush'},{m:22,t:'elite'},{m:23,t:'ring'},{m:24,t:'swarm'},{m:25,t:'everything'},{m:26,t:'elite'},{m:27,t:'rush'},{m:28,t:'ring'},{m:29,t:'elite'},
 {m:30,t:'boss'}];
const DIFF={easy:{name:'Easy',hp:1,dmg:1,spawn:1,silver:1},medium:{name:'Medium',hp:1.6,dmg:1.35,spawn:1.3,silver:1.75},hard:{name:'Hard',hp:2.6,dmg:1.8,spawn:1.7,silver:3}};
const CHARS={
 birb:{name:'Birb',icon:'birb',weapon:'volley',perk:'+10% XP',cost:0,mod:S=>S.growth+=.1},
 parrot:{name:'Parrot',icon:'parrot',weapon:'parrot',perk:'+10% damage',cost:400,mod:S=>S.might+=.1},
 crow:{name:'Crow',icon:'crow',weapon:'crowpick',perk:'+15% armor',cost:700,mod:S=>S.armor+=.15},
 sparrow:{name:'Sparrow',icon:'sparrow',weapon:'seed',perk:'+15% move speed',cost:1000,mod:S=>S.speed*=1.15},
 seagull:{name:'Seagull',icon:'seagull',weapon:'gull',perk:'+1 projectile',cost:1500,mod:S=>S.amount+=1},
};
const META=[
 {id:'might',name:'Might',desc:'+5% damage per level',max:5,base:120,f:(S,l)=>S.might+=.05*l},
 {id:'maxhp',name:'Vitality',desc:'+10 max HP per level',max:5,base:100,f:(S,l)=>S.maxhp+=10*l},
 {id:'armor',name:'Armor',desc:'+4% armor per level',max:5,base:150,f:(S,l)=>S.armor+=.04*l},
 {id:'regen',name:'Recovery',desc:'+0.1 HP/s per level',max:5,base:150,f:(S,l)=>S.regen+=.1*l},
 {id:'speed',name:'Swiftness',desc:'+3% move speed per level',max:5,base:120,f:(S,l)=>S.speed*=1+.03*l},
 {id:'magnet',name:'Magnet',desc:'+12% pickup range per level',max:5,base:100,f:(S,l)=>S.magnet*=1+.12*l},
 {id:'cooldown',name:'Haste',desc:'-2.5% cooldown per level',max:4,base:200,f:(S,l)=>S.cooldown*=1-.025*l},
 {id:'luck',name:'Luck',desc:'+5% luck per level',max:4,base:200,f:(S,l)=>S.luck+=.05*l},
 {id:'growth',name:'Growth',desc:'+4% XP per level',max:5,base:150,f:(S,l)=>S.growth+=.04*l},
 {id:'greed',name:'Greed',desc:'+10% gold per level',max:5,base:100,f:(S,l)=>S.greed+=.1*l},
 {id:'reroll',name:'Reroll',desc:'+1 reroll per run',max:3,base:300,f:(S,l)=>S.rerolls+=l},
 {id:'banish',name:'Banish',desc:'+1 banish per run',max:3,base:300,f:(S,l)=>S.banishes+=l},
 {id:'skip',name:'Skip',desc:'+1 skip per run',max:3,base:200,f:(S,l)=>S.skips+=l},
 {id:'revival',name:'Revival',desc:'Revive once per run',max:1,base:2000,f:(S,l)=>S.revival+=l},
 {id:'amount',name:'Amount',desc:'+1 projectile for every weapon',max:1,base:3000,f:(S,l)=>S.amount+=l},
];
const metaCost=(m,l)=>Math.round(m.base*Math.pow(1.6,l));
