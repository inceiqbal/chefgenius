// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 5;

  @override
  Recipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recipe(
      id: fields[0] as int,
      title: fields[1] as String,
      description: fields[2] as String,
      duration: fields[3] as String,
      servings: fields[4] as String,
      imageUrl: fields[5] as String,
      mainIngredients: (fields[6] as List).cast<String>(),
      allIngredients: (fields[7] as List).cast<Ingredient>(),
      steps: (fields[8] as List).cast<String>(),
      score: fields[9] as double,
      isFavorite: fields[10] as bool,
      isAiGenerated: fields[11] as bool,
      halalStatus: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.duration)
      ..writeByte(4)
      ..write(obj.servings)
      ..writeByte(5)
      ..write(obj.imageUrl)
      ..writeByte(6)
      ..write(obj.mainIngredients)
      ..writeByte(7)
      ..write(obj.allIngredients)
      ..writeByte(8)
      ..write(obj.steps)
      ..writeByte(9)
      ..write(obj.score)
      ..writeByte(10)
      ..write(obj.isFavorite)
      ..writeByte(11)
      ..write(obj.isAiGenerated)
      ..writeByte(12)
      ..write(obj.halalStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
