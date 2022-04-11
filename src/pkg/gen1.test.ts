import {Dex} from '@pkmn/sim';
import {Generations} from '@pkmn/data';

import {LAYOUT, Data, Lookup} from './data';
import {Battle} from './gen1';

const BUFFER = Data.buffer([
  0x11, 0x01, 0xda, 0x00, 0x16, 0x01, 0x9e, 0x00, 0xce, 0x00, 0x9b, 0x03, 0x4b, 0x0f, 0x2a, 0x18,
  0x52, 0x0a, 0x0c, 0x01, 0x08, 0x6e, 0x33, 0x64, 0x07, 0x01, 0x02, 0x01, 0xb2, 0x00, 0xee, 0x00,
  0x9e, 0x00, 0x1b, 0x03, 0x18, 0x1e, 0x77, 0x0e, 0x24, 0x11, 0xd3, 0x00, 0x05, 0x55, 0x20, 0x64,
  0x33, 0x01, 0xc0, 0x00, 0xd4, 0x00, 0xa2, 0x00, 0xa2, 0x00, 0x13, 0x16, 0x23, 0x1f, 0x25, 0x01,
  0x09, 0x04, 0x48, 0x00, 0x00, 0x3e, 0x19, 0x64, 0x17, 0x01, 0x7c, 0x00, 0x82, 0x00, 0x68, 0x00,
  0x9a, 0x00, 0x11, 0x23, 0x85, 0x0f, 0x10, 0x04, 0x1f, 0x1f, 0x0c, 0x01, 0x00, 0x23, 0x00, 0x64,
  0x09, 0x01, 0xce, 0x00, 0xa8, 0x00, 0xb2, 0x00, 0xb2, 0x00, 0x20, 0x02, 0x7d, 0x1c, 0x60, 0x2c,
  0x11, 0x1a, 0x5c, 0x00, 0x00, 0x94, 0xee, 0x64, 0xf3, 0x00, 0x9e, 0x00, 0xe4, 0x00, 0xb2, 0x00,
  0x16, 0x01, 0x9b, 0x08, 0xa4, 0x02, 0x0d, 0x09, 0x73, 0x12, 0x9e, 0x00, 0x00, 0x52, 0xbb, 0x64,
  0x11, 0x01, 0xda, 0x00, 0x16, 0x01, 0x9e, 0x00, 0xce, 0x00, 0xeb, 0x00, 0x2a, 0x42, 0x42, 0x03,
  0x82, 0x04, 0x00, 0x9b, 0x03, 0x4b, 0x0f, 0x2a, 0x18, 0x52, 0x0a, 0x00, 0x00, 0x30, 0x6e, 0x33,
  0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x00, 0x11, 0x2f, 0x01, 0xb2, 0x00, 0xa8, 0x00, 0xee, 0x00,
  0x16, 0x01, 0x93, 0x15, 0x46, 0x07, 0x1c, 0x16, 0xa1, 0x0e, 0xbc, 0x00, 0x00, 0x49, 0x39, 0x64,
  0x07, 0x01, 0x86, 0x00, 0x80, 0x00, 0x7a, 0x00, 0xda, 0x00, 0x7c, 0x01, 0x29, 0x01, 0x8f, 0x00,
  0x18, 0x18, 0x7e, 0x00, 0x00, 0x60, 0xcc, 0x64, 0x2f, 0x01, 0xde, 0x00, 0xa8, 0x00, 0xae, 0x00,
  0xc6, 0x00, 0x8e, 0x10, 0x6f, 0x09, 0x78, 0x05, 0x4d, 0x15, 0xd6, 0x00, 0x04, 0x77, 0x99, 0x64,
  0xd5, 0x00, 0xb2, 0x00, 0x94, 0x00, 0x58, 0x00, 0x94, 0x00, 0x83, 0x03, 0x37, 0x00, 0x94, 0x17,
  0x95, 0x13, 0xb9, 0x00, 0x00, 0x2e, 0xa6, 0x64, 0x17, 0x01, 0xc2, 0x00, 0x86, 0x00, 0x68, 0x00,
  0x68, 0x00, 0x35, 0x08, 0x65, 0x10, 0x0e, 0x24, 0x08, 0x17, 0x15, 0x00, 0x08, 0x42, 0x11, 0x64,
  0x01, 0x01, 0xa0, 0x00, 0xc2, 0x00, 0x96, 0x00, 0xa4, 0x00, 0x43, 0x20, 0x68, 0x10, 0x9b, 0x01,
  0x24, 0x0c, 0x16, 0x00, 0x00, 0x08, 0x99, 0x64, 0x2f, 0x01, 0xb2, 0x00, 0xa8, 0x00, 0xee, 0x00,
  0x16, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x93, 0x15, 0x46, 0x07, 0x1c,
  0x16, 0xa1, 0x0e, 0x00, 0x00, 0xe0, 0x49, 0x39, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x68, 0x00,
  0xc3, 0x01, 0x37, 0x01, 0x00, 0x88, 0xc7, 0x28, 0x6c, 0x96, 0x72, 0x1a, 0x45, 0xe0, 0xcc, 0x08,
]);

const P1_ORDER = LAYOUT[0].offsets.Battle.p1 + LAYOUT[0].offsets.Side.order;

describe('Gen 1', () => {
  const gens = new Generations(Dex as any);
  const gen = gens.get(1);
  const lookup = Lookup.get(gen);

  it('serialize/deserialize', () => {
    const battle = new Battle(lookup, new DataView(BUFFER.buffer), {});
    const restored = Battle.restore(gen, lookup, battle, {});
    // NOTE: Jest object diffing toJSON is super slow so we compare strings instead...
    expect(JSON.stringify(restored)).toEqual(JSON.stringify(battle));

    expect(battle.turn).toBe(451);
    expect(battle.lastDamage).toBe(311);
    expect(battle.prng).toEqual([
      224, 204, 136, 199, 40,
      108, 150, 114, 26, 69,
    ]);

    const p1 = battle.side('p1');
    expect(p1.lastUsedMove).toBe('wingattack');

    const slot1 = p1.active!;
    const slot2 = p1.get(2)!;

    expect(slot1.species).toBe('weezing');
    expect(slot1.stored.species).toBe('weezing');
    expect(slot1.hp).toBe(268);
    expect(slot1.status).toBe('tox');
    expect(slot1.statusData.toxic).toBe(4);
    expect(slot1.volatiles).toEqual({
      confusion: {duration: 2},
      thrashing: {duration: 3, accuracy: 235},
      substitute: {hp: 42},
    });
    expect(slot1.stats.atk).toBe(218);
    expect(slot1.stored.stats.atk).toBe(218);
    expect(slot1.boost('evasion')).toBe(3);
    expect(slot1.move(1)).toEqual({id: 'bonemerang', pp: 3});
    expect(slot1.move(2)).toEqual({id: 'razorleaf', pp: 15, disabled: 4});
    expect(slot1.active).toBe(true);

    expect(slot2.species).toBe('dodrio');
    expect(slot2.stored.species).toBe('dodrio');
    expect(slot2.types).toEqual(['Normal', 'Flying']);
    expect(slot2.hp).toBe(211);
    expect(slot2.status).toBe('slp');
    expect(slot2.statusData.sleep).toBe(5);
    expect(slot2.active).toBe(false);

    const p2 = battle.side('p2');
    expect(p2.lastSelectedMove).toBe('doubleteam');
    expect(p2.active!.species).toBe('tentacruel');
    expect(p2.active!.types).toEqual(['Water', 'Poison']);
    expect(p2.active!.hp).toBe(188);
    expect(p2.active!.stats.spa).toBe(278);
    expect(p2.active!.move(2)).toEqual({id: 'strength', pp: 7});
    expect(p2.active!.boosts.evasion).toBe(-2);

    const pos = BUFFER[P1_ORDER];
    BUFFER[P1_ORDER] = BUFFER[P1_ORDER + 1];
    BUFFER[P1_ORDER + 1] = pos;

    expect(slot1.active).toBe(false);
    expect(slot1.boosts.evasion).toBe(0);
    expect(slot2.active).toBe(true);
    expect(slot2.boosts.evasion).toBe(3);
    expect(slot2.species).toBe('weezing');
    expect(slot2.stored.species).toBe('dodrio');
  });
});
