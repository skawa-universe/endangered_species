import "dart:convert" show JSON;
import "dart:async";
import "dart:io";
import "dart:math" as math;
import "package:entify/entify.dart";
import "package:http/http.dart" as http;
import "package:googleapis_auth/auth_io.dart" as auth;
import "package:googleapis/datastore/v1.dart" as ds;

// Change these to your local settings
const String credentialsPath = "datastoreCredentials.json";
final bool localDevelopment = !new File(credentialsPath).existsSync();
// Replace this with your own app id if you're using the Cloud Datastore,
// and not the emulator
const String appId = "species";

// Standard boilerplate code for getting a googleapis DatastoreApi object

Future<http.Client> getClient() async {
  if (localDevelopment) {
    print("local development, using no credentials");
    return new http.Client();
  }
  String credentials = await new File(credentialsPath).readAsString();
  return auth.clientViaServiceAccount(
      new auth.ServiceAccountCredentials.fromJson(credentials),
      [ds.DatastoreApi.DatastoreScope]);
}

Future<ds.DatastoreApi> getDatastoreApi() async {
  http.Client client = await getClient();
  if (localDevelopment) {
    print("local development, using datastore at localhost:8081\n");
    return new ds.DatastoreApi(client, rootUrl: "http://localhost:8081/");
  }
  print("Using Google Cloud Datastore\n");
  return new ds.DatastoreApi(client);
}

Future<DatastoreShell> getDatastoreShell() =>
    getDatastoreApi().then((api) => new DatastoreShell(api, appId));

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

/// Fills the database with the
Future<Null> populate(List<String> args) async {
  Future<DatastoreShell> datastoreFuture = getDatastoreShell();
  File source = new File("endangered_species.json");
  String speciesJson = await source.readAsString();
  Map<String, dynamic> allSpecSpec = JSON.decode(speciesJson);
  String fieldNames = allSpecSpec["fields"];
  int commonNameIndex = fieldNames.indexOf("Name");
  int sciNameIndex = fieldNames.indexOf("Scientific name");
  int statusIndex = fieldNames.indexOf("Status");
  int firstTaxon =
      math.max(math.max(commonNameIndex, sciNameIndex), statusIndex) + 1;
  List<Species> species = [];
  for (List<String> values in allSpecSpec["data"]) {
    Species spec = new Species();
    spec.scientificName = values[sciNameIndex];
    spec.commonName = values[commonNameIndex];
    spec.status = values[statusIndex];
    int len = values.length;
    for (int i = firstTaxon; i < len; ++i) {
      String rank = fieldNames[i];
      String name = values[i];
      if (name != null) spec.taxonomy.add(new Taxon(rank, name));
    }
    species.add(spec);
  }
  DatastoreShell dsh = await datastoreFuture;
  ds.CommitResponse result =
      await (dsh.beginMutation()..upsertAll(species.map((s) => s.toEntity()))).executeRaw();
  print("${species.length} entities written");
  if (args.contains("--dump-response")) print(JSON.encode(result.toJson()));
  exit(0);
}

/// Queries the endangered species database.
///
/// Two kinds of queries are supported:
///
/// 1. Taxonomic hierarchy query: a `<taxon>` is represented with
///   the format `<rank>:<name>`, using these the following can
///   be queried:
///   - `/<taxon>/<taxon>/` will list the very next level
///     (`/` will list the very first level)
///   - `/<taxon>/<taxon>/**` will list the whole subtree
///     (`/**` will list all the available paths)
/// 2. Taxon (rank) query
///   - `<rank>[:]` will list all the taxons with that rank
///   - `<rank>:<name>` (so basically a `<taxon>`) will list all
///     the species that has the specified taxon
Future<Null> query(List<String> args) async {
  // We use a small batch size for demonstration purposes.
  const int batchSize = 10;

  DatastoreShell dsh = await getDatastoreShell();

  String prefix = args.last;

  // set to `true` if the query contains a projection.
  bool projected = false;
  Query listQuery = new Query(Species.bridge.kind)..limit = batchSize;

  // if the prefix (basically the query string) does not start with a slash
  // it is a taxon (rank) query.
  bool taxonomyElement = !prefix.startsWith("/");

  if (taxonomyElement) {
    bool rankSearch = prefix.endsWith(":") || !prefix.contains(":");
    if (prefix.endsWith(":")) prefix = prefix.substring(0, prefix.length - 1);

    if (rankSearch) {
      // The filters are basically a search for the query string as a prefix.
      // Every value that has the prefix is greater than or equal "$prefix:",
      // and less than with the same string but the last character is changed
      // to the next ASCII character.
      listQuery
        ..filter = new CompoundFilter.and([
          FilterOperator.greaterThanOrEqual("taxonomy", "${prefix}:"),
          FilterOperator.lessThan("taxonomy", "${prefix};"),
        ])
        ..projection = [new Projection("taxonomy", distinct: true)];
      projected = true;
    } else {
      listQuery.filter = FilterOperator.equal("taxonomy", prefix);
    }
  } else {
    bool subtree = false;
    if (prefix.endsWith("**")) {
      subtree = true;
      // remove the asterisks
      prefix = prefix.substring(0, prefix.length - 2);
    }
    if (prefix.endsWith("/")) prefix = prefix.substring(0, prefix.length - 1);

    // see an explanation of prefix queries above
    listQuery
      ..filter = subtree
          ? new CompoundFilter.and([
              FilterOperator.greaterThanOrEqual("taxonomyPaths", "${prefix}/"),
              FilterOperator.lessThan("taxonomyPaths", "${prefix}0"),
            ])
          : new CompoundFilter.and([
              FilterOperator.greaterThanOrEqual("taxonomyPaths", "${prefix}/ "),
              FilterOperator.lessThan("taxonomyPaths", "${prefix}/!"),
            ])
      ..projection = [new Projection("taxonomyPaths", distinct: true)];
    projected = true;
  }
  Stopwatch watch = new Stopwatch();
  watch.start();
  QueryResultBatch batch = await dsh.prepareQuery(listQuery).runQuery();
  int batchCount = 1;
  while (batch.entities != null && batch.entities.isNotEmpty) {
    if (projected) {
      print(batch.entities
          .map((e) => (e["taxonomyPaths"] ?? e["taxonomy"] as String)
              .replaceAll("/ ", "/"))
          .join("\n"));
    } else {
      print(batch.entities.map((e) {
        Species s = new Species.fromEntity(e);
        return "${s.scientificName}, commonly known as ${s.commonName}"
            " is \"${s.status}\"\nTaxonomy: /${s.fullTaxonomyPath}";
      }).join("\n"));
    }
    listQuery.startCursor = batch.endCursor;
    // if we don't have enough results, it may be probably because this is
    // the last batch
    if (batch.entities.length < batchSize) break;
    batch = await dsh.prepareQuery(listQuery).runQuery();
    ++batchCount;
  }
  watch.stop();
  print("\nQuery took ${watch.elapsed} with batch size ${batchSize} "
    "($batchCount batch${batchCount != 1 ? 'es' : ''})\n");
  exit(0);
}

Future<Null> main(List<String> args) async {
  if (args.length == 0) {
    print("Valid commands are:");
    print("  - populate");
    print("  - query");
  }

  switch (args[0]) {
    case "populate":
      await populate(args.sublist(1));
      break;
    case "query":
      await query(args.sublist(1));
      break;
    default:
      print("Que?");
      break;
  }
}
