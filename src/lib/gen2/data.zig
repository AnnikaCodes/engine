const std = @import("std");
const builtin = @import("builtin");

const pkmn = @import("../pkmn.zig");

const data = @import("../common/data.zig");
const DEBUG = @import("../common/debug.zig").print;
const rng = @import("../common/rng.zig");
const util = @import("../common/util.zig");

const items = @import("data/items.zig");
const moves = @import("data/moves.zig");
const species = @import("data/species.zig");
const types = @import("data/types.zig");

const gen1 = @import("../gen1/data.zig");

const mechanics = @import("mechanics.zig");

const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

pub const MAX_CHOICES: usize = 9; // move 1..4, switch 2..6
pub const MAX_LOGS: usize = 180; // TODO

pub const CHOICES_SIZE = if (builtin.mode == .ReleaseSmall)
    MAX_CHOICES
else
    std.math.ceilPowerOfTwo(usize, MAX_CHOICES) catch unreachable;
pub const LOGS_SIZE = if (builtin.mode == .ReleaseSmall)
    MAX_LOGS
else
    std.math.ceilPowerOfTwo(usize, MAX_LOGS) catch unreachable;

const Choice = data.Choice;
const ID = data.ID;
const Player = data.Player;
const Result = data.Result;

const PointerType = util.PointerType;

const showdown = pkmn.options.showdown;

pub const PRNG = rng.PRNG(2);

pub fn Battle(comptime RNG: anytype) type {
    return extern struct {
        const Self = @This();

        sides: [2]Side,
        rng: RNG,
        turn: u16 = 0,
        field: Field = .{},

        pub inline fn side(self: anytype, player: Player) PointerType(@TypeOf(self), Side) {
            assert(@typeInfo(@TypeOf(self)).Pointer.child == Self);
            return &self.sides[@intFromEnum(player)];
        }

        pub inline fn foe(self: anytype, player: Player) PointerType(@TypeOf(self), Side) {
            assert(@typeInfo(@TypeOf(self)).Pointer.child == Self);
            return &self.sides[@intFromEnum(player.foe())];
        }

        pub inline fn active(self: *const Self, player: Player) ID {
            return player.ident(@intCast(self.side(player).pokemon[0].position));
        }

        pub fn update(self: *Self, c1: Choice, c2: Choice, options: anytype) !Result {
            return mechanics.update(self, c1, c2, options);
        }

        pub fn choices(self: *Self, player: Player, request: Choice.Type, out: []Choice) u8 {
            return mechanics.choices(self, player, request, out);
        }
    };
}

// TODO
test Battle {
    try expectEqual(496, @sizeOf(Battle(PRNG)));
}

const Field = packed struct {
    weather: Weather = .None,
    weather_duration: u4 = 0,

    comptime {
        assert(@sizeOf(Field) == 1);
    }
};

const Weather = enum(u4) {
    None,
    Rain,
    Sun,
    Sandstorm,
};

const Side = extern struct {
    pokemon: [6]Pokemon = [_]Pokemon{.{}} ** 6,
    active: ActivePokemon = .{},
    conditions: Conditions,
    last_used_move: Move = .None,
    _: u8 = 0,

    const Conditions = packed struct {
        Spikes: bool = false,
        Safeguard: bool = false,
        LightScreen: bool = false,
        Reflect: bool = false,

        safeguard: u4 = 0,
        light_screen: u4 = 0,
        reflect: u4 = 0,

        comptime {
            assert(@sizeOf(Conditions) == 2);
        }
    };

    comptime {
        assert(@sizeOf(Side) == 240);
    }

    pub inline fn get(self: anytype, slot: u8) PointerType(@TypeOf(self), Pokemon) {
        assert(@typeInfo(@TypeOf(self)).Pointer.child == Side);
        assert(slot > 0 and slot <= 6);
        const id = self.pokemon[slot - 1].position;
        assert(id > 0 and id <= 6);
        return &self.pokemon[id - 1];
    }

    pub inline fn stored(self: anytype) PointerType(@TypeOf(self), Pokemon) {
        assert(@typeInfo(@TypeOf(self)).Pointer.child == Side);
        return self.get(1);
    }
};

// NOTE: DVs (Gender & Hidden Power) and Happiness are stored only in Pokemon
const ActivePokemon = extern struct {
    volatiles: Volatile align(4) = .{},
    stats: Stats(u16) = .{},
    moves: [4]MoveSlot = [_]MoveSlot{.{}} ** 4,
    boosts: Boosts = .{},
    species: Species = .None,
    item: Item = .None,
    last_move: Move = .None,
    _: u8 = 0,

    comptime {
        assert(@sizeOf(ActivePokemon) == 44);
    }

    pub inline fn move(self: anytype, mslot: u8) PointerType(@TypeOf(self), MoveSlot) {
        assert(@typeInfo(@TypeOf(self)).Pointer.child == Pokemon);
        assert(mslot > 0 and mslot <= 4);
        assert(self.moves[mslot - 1].id != .None);
        return &self.moves[mslot - 1];
    }
};

const Pokemon = extern struct {
    stats: Stats(u16) = .{},
    moves: [4]MoveSlot = [_]MoveSlot{.{}} ** 4,
    types: Types = .{},
    dvs: DVs = .{},
    hp: u16 = 0,
    status: u8 = 0,
    species: Species = .None,
    level: u8 = 100,
    item: Item = .None,
    happiness: u8 = 255,
    position: u8 = 0,

    comptime {
        assert(@sizeOf(Pokemon) == 32);
    }

    pub inline fn move(self: anytype, mslot: u8) PointerType(@TypeOf(self), MoveSlot) {
        assert(@typeInfo(@TypeOf(self)).Pointer.child == Pokemon);
        assert(mslot > 0 and mslot <= 4);
        assert(self.moves[mslot - 1].id != .None);
        return &self.moves[mslot - 1];
    }
};

pub const Gender = enum(u2) {
    Male,
    Female,
    Unknown,
};

const DVs = packed struct {
    gender: Gender = .Male,
    pow: u6 = 40,
    type: Type = .Dark,

    pub fn init(g: Gender, p: u6, t: Type) DVs {
        assert(p >= 1 and p <= 40);
        assert(t != .Normal and t != .@"???");
        return DVs{ .gender = g, .pow = p, .type = t };
    }

    pub inline fn power(dvs: DVs) u8 {
        return @as(u8, dvs.pow) + 30;
    }

    pub fn from(specie: Species, dvs: gen1.DVs) DVs {
        const ratio = Species.get(specie).ratio;
        const g: Gender = switch (ratio) {
            0x00 => .Male,
            0xFE => .Female,
            0xFF => .Unknown,
            else => if ((@as(u8, dvs.atk) << 4 | dvs.spe) < ratio) Gender.Female else Gender.Male,
        };
        const p: u6 = @intCast(1 + ((5 * @as(u8, (dvs.atk & 0b1000) | ((dvs.def & 0b1000)) >> 1 |
            ((dvs.spe & 0b1000)) >> 2 | ((dvs.spc & 0b1000)) >> 3) + (dvs.spc & 0b0011)) >> 1));
        var t = @as(u8, dvs.def & 0b0011) + (@as(u8, dvs.atk & 0b0011) << 2) + 1;
        if (t >= @intFromEnum(Type.@"???")) t = t + 1;
        return DVs{ .gender = g, .pow = p, .type = @enumFromInt(t) };
    }

    comptime {
        assert(@sizeOf(DVs) == 2);
    }
};

test DVs {
    var dvs = DVs.from(.Mewtwo, .{ .def = 13 });
    try expectEqual(Gender.Unknown, dvs.gender);
    try expectEqual(Type.Ice, dvs.type);
    try expectEqual(@as(u8, 70), dvs.power());

    dvs = DVs.from(.Pikachu, .{ .spc = 14 });
    try expectEqual(Gender.Male, dvs.gender);
    try expectEqual(Type.Dark, dvs.type);
    try expectEqual(@as(u8, 69), dvs.power());

    dvs = DVs.from(.Cyndaquil, .{ .atk = 1, .def = 3, .spe = 10, .spc = 9 });
    try expectEqual(Gender.Female, dvs.gender);
    dvs = DVs.from(.Cyndaquil, .{ .atk = 14, .def = 7, .spe = 11, .spc = 2 });
    try expectEqual(Gender.Male, dvs.gender);
    dvs = DVs.from(.Sandshrew, .{ .atk = 7, .def = 10, .spe = 10, .spc = 10 });
    try expectEqual(Gender.Female, dvs.gender);
    dvs = DVs.from(.Sandshrew, .{ .atk = 6, .def = 15, .spe = 7, .spc = 5 });
    try expectEqual(Gender.Female, dvs.gender);
}

const MoveSlot = packed struct {
    id: Move = .None,
    pp_ups: u2 = 3,
    pp: u6 = 0,

    comptime {
        assert(@sizeOf(MoveSlot) == 2);
    }
};

pub const Status = gen1.Status;

const Volatile = packed struct {
    Bide: bool = false,
    Thrashing: bool = false,
    Flinch: bool = false,
    Charging: bool = false,
    Underground: bool = false,
    Flying: bool = false,
    Confusion: bool = false,
    Mist: bool = false,
    FocusEnergy: bool = false,
    Substitute: bool = false,
    Recharging: bool = false,
    Rage: bool = false,
    LeechSeed: bool = false,
    Toxic: bool = false,
    Transform: bool = false,

    Nightmare: bool = false,
    Cure: bool = false,
    Protect: bool = false,
    Foresight: bool = false,
    PerishSong: bool = false,
    Endure: bool = false,
    Rollout: bool = false,
    Attract: bool = false,
    DefenseCurl: bool = false,
    Encore: bool = false,
    LockOn: bool = false,
    DestinyBond: bool = false,
    BeatUp: bool = false,

    trapped: bool = false,
    switched: bool = false,
    switching: bool = false,

    _: u5 = 0,

    bind: u4 = 0,
    future_sight: FutureSight = .{},
    bide: u16 = 0,
    disabled: Disabled = .{},
    rage: u8 = 0,
    substitute: u8 = 0,
    toxic: u8 = 0,
    confusion: u4 = 0,
    encore: u4 = 0,
    fury_cutter: u4 = 0,
    perish_song: u4 = 0,
    protect: u4 = 0,
    rollout: u4 = 0,

    const Disabled = packed struct {
        move: u4 = 0,
        duration: u4 = 0,
    };

    const FutureSight = packed struct {
        damage: u12 = 0,
        count: u4 = 0,
    };

    comptime {
        assert(@sizeOf(Volatile) == 16);
    }
};

pub fn Stats(comptime T: type) type {
    return extern struct {
        hp: T = 0,
        atk: T = 0,
        def: T = 0,
        spe: T = 0,
        spa: T = 0,
        spd: T = 0,

        pub fn calc(comptime stat: []const u8, base: T, dv: u4, exp: u16, level: u8) T {
            assert(level > 0 and level <= 100);
            const float: f32 = @floatFromInt(exp);
            const evs: u16 = @min(255, @as(u16, @intFromFloat(@ceil(@sqrt(float)))));
            const core: u32 = (2 *% (@as(u32, base) +% dv)) +% (evs / 4);
            const factor: u32 = if (std.mem.eql(u8, stat, "hp")) level + 10 else 5;
            return @intCast(core *% @as(u32, level) / 100 +% factor);
        }
    };
}

test Stats {
    try expectEqual(12, @sizeOf(Stats(u16)));
    const stats = Stats(u8){ .spd = 2, .spe = 3 };
    try expectEqual(2, stats.spd);
    try expectEqual(0, stats.def);

    var base = Species.get(.Gyarados).stats;
    try expectEqual(@as(u16, 127), Stats(u16).calc("hp", base.hp, 0, 5120, 38));
    base = Species.get(.Pidgeot).stats;
    try expectEqual(@as(u16, 279), Stats(u16).calc("spe", base.spe, 15, 63001, 100));
}

pub const Boosts = packed struct {
    atk: i4 = 0,
    def: i4 = 0,
    spe: i4 = 0,
    spa: i4 = 0,
    spd: i4 = 0,
    accuracy: i4 = 0,
    evasion: i4 = 0,
    _: i4 = 0,

    comptime {
        assert(@sizeOf(Boosts) == 4);
    }
};

test Boosts {
    const boosts = Boosts{ .spd = -6 };
    try expectEqual(0, boosts.atk);
    try expectEqual(-6, boosts.spd);
}

pub const Item = items.Item;

test Item {
    try expect(Item.boost(.MasterBall) == null);
    try expectEqual(Type.Normal, Item.boost(.PinkBow).?);
    try expectEqual(Type.Normal, Item.boost(.PolkadotBow).?);
    try expectEqual(Type.Dark, Item.boost(.BlackGlasses).?);

    try expect(!Item.mail(.UpGrade));
    try expect(Item.mail(.FlowerMail));
    try expect(Item.mail(.MirageMail));
    try expect(!Item.mail(.TownMap));

    try expect(!Item.berry(.LightBall));
    try expect(Item.berry(.PSNCureBerry));
    try expect(Item.berry(.GoldBerry));
    try expect(!Item.berry(.MasterBall));
}

pub const Move = moves.Move;

test Move {
    try expectEqual(251, @intFromEnum(Move.BeatUp));
    const move = Move.get(.DynamicPunch);
    try expectEqual(Move.Effect.ConfusionChance, move.effect);
    try expectEqual(@as(u8, 50), move.accuracy);
    try expectEqual(@as(u8, 5), move.pp);
}

pub const Species = species.Species;

test Species {
    try expectEqual(152, @intFromEnum(Species.Chikorita));
    try expectEqual(@as(u8, 100), Species.get(.Celebi).stats.spd);
}

pub const Type = types.Type;
pub const Types = types.Types;
pub const Effectiveness = gen1.Effectiveness;

test Types {
    try expectEqual(13, @intFromEnum(Type.Electric));

    try expect(!Type.Steel.special());
    try expect(Type.Dark.special());

    try expectEqual(@as(u8, 3), Type.Water.precedence());
    try expect(Type.Bug.precedence() > Type.Poison.precedence());

    try expectEqual(Effectiveness.Super, Type.effectiveness(.Ghost, .Psychic));
    try expectEqual(Effectiveness.Super, Type.effectiveness(.Water, .Fire));
    try expectEqual(Effectiveness.Resisted, Type.effectiveness(.Fire, .Water));
    try expectEqual(Effectiveness.Neutral, Type.effectiveness(.Normal, .Grass));
    try expectEqual(Effectiveness.Immune, Type.effectiveness(.Poison, .Steel));
}
