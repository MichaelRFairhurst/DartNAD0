const r1d4 = Dice(rolls: 1, sides: 4);
const r2d4 = Dice(rolls: 2, sides: 4);
const r3d4 = Dice(rolls: 3, sides: 4);
const r4d4 = Dice(rolls: 4, sides: 4);
const r1d6 = Dice(rolls: 1, sides: 6);
const r2d6 = Dice(rolls: 2, sides: 6);
const r3d6 = Dice(rolls: 3, sides: 6);
const r4d6 = Dice(rolls: 4, sides: 6);
const r5d6 = Dice(rolls: 5, sides: 6);
const r6d6 = Dice(rolls: 6, sides: 6);
const r1d8 = Dice(rolls: 1, sides: 8);
const r2d8 = Dice(rolls: 2, sides: 8);
const r3d8 = Dice(rolls: 3, sides: 8);
const r4d8 = Dice(rolls: 4, sides: 8);
const r1d10 = Dice(rolls: 1, sides: 10);
const r2d10 = Dice(rolls: 2, sides: 10);
const r3d10 = Dice(rolls: 3, sides: 10);
const r4d10 = Dice(rolls: 4, sides: 10);
const r1d12 = Dice(rolls: 1, sides: 12);
const r2d12 = Dice(rolls: 2, sides: 12);
const r3d12 = Dice(rolls: 3, sides: 12);
const r4d12 = Dice(rolls: 4, sides: 12);
const r1d20 = Dice(rolls: 1, sides: 20);
const r2d20 = Dice(rolls: 2, sides: 20);
const r3d20 = Dice(rolls: 3, sides: 20);
const r4d20 = Dice(rolls: 4, sides: 20);

class Dice {
  const Dice({
    required this.rolls,
    required this.sides,
  });

  final int rolls;
  final int sides;

  Dice copyWith({
    int? rolls,
    int? sides,
  }) =>
      Dice(
        rolls: rolls ?? this.rolls,
        sides: sides ?? this.sides,
      );

  double get expectedValue => rolls * (sides + 1) / 2;

  @override
  int get hashCode => Object.hashAll([rolls, sides]);

  @override
  bool operator==(Object? other) => other is Dice && other.sides == sides && other.rolls == rolls;
}
