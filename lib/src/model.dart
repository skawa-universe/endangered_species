import "package:entify/entify.dart";

/// Represents a taxon, a classification level with the name.
///
/// For example the "Class" rank with the name "Aves" represents
/// the taxonomical class of birds). The string representation of this
/// taxon is "Class:Aves". The colon (`:`) character is forbidden in
/// both the [rank] and the [name].
class Taxon {
  /// Creates a Taxon by providing a separate rank and name string.
  Taxon(this.rank, this.name);

  /// Creates a Taxon from the string representation.
  ///
  /// For example the "Order:Rodentia" represents the taxon with the
  /// rank "Order" and name "Rodentia" (commonly called as rodents).
  Taxon.fromString(String encoded) {
    int colon = encoded.indexOf(":");
    rank = encoded.substring(0, colon);
    name = encoded.substring(colon + 1);
  }

  /// Creates a Taxon from the string representation or returns `null`
  /// if the provided parameter is `null`.
  static Taxon fromNullableString(String encoded) =>
      encoded == null ? null : new Taxon.fromString(encoded);

  /// Converts the taxon object to the string representation.
  String toString() => "$rank:$name";

  /// The rank of the taxon (for example: "Species").
  String rank;

  /// The name of the taxon (for example: "E. robustus").
  String name;
}

/// Represents a group of living organisms.
///
/// Species is a kind of a misnomer, technically we use them
/// not only for endangered species, but families too).
@entityModel
class Species {
  /// The bridge instance for this class.
  static final EntityBridge<Species> bridge = new EntityBridge<Species>();

  Species();

  /// Creates a Species object from the [Entity] representation.
  factory Species.fromEntity(Entity e) => bridge.fromEntity(e, new Species());

  /// An alternative implementation for creating a Species object included as
  /// an example.
  Species.entity(Entity e) {
    bridge.fromEntity(e, this);
  }

  /// Converts the Species object to an [Entity] object.
  Entity toEntity() => bridge.toEntity(this);

  /// The scientific (Latin) name of the species (used as [Entity] key)
  @primaryKey
  String scientificName;

  /// The common English name of the species.
  @persistent
  String commonName;

  /// The endangerment status.
  @persistent
  String status;

  /// A special serializer for the [taxonomy] field.
  @Persistent(name: "taxonomy")
  List<String> get taxonomyField => taxonomy.map((e) => e.toString()).toList();

  /// A special deserializer for the [taxonomy] field.
  void set taxonomyField(List<String> encodedTaxonomy) {
    taxonomy = encodedTaxonomy?.map(Taxon.fromNullableString)?.toList();
  }

  /// The list of [Taxon]s that applies to this species.
  List<Taxon> taxonomy = [];

  /// A lookup field that enables listing taxonomic hierarchy levels.
  @persistent
  List<String> get taxonomyPaths {
    List<String> result = [];
    int excludingLast = taxonomy.length - 1;
    for (int i = 0; i < excludingLast; ++i) {
      String prefix = taxonomy.sublist(0, i).join('/');
      result.add("${i > 0 ? '/' : ''}${prefix}/ ${taxonomy[i]}");
    }
    return result;
  }

  // An empty setter, because EntityBridge requires a setter.
  void set taxonomyPaths(List<String> doesntMatter) {}

  /// A nonpersistent calculated field to print the taxonomic "path".
  String get fullTaxonomyPath => taxonomy.join('/');
}
