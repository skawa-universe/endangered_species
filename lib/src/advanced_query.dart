import "dart:async";
import "package:entify/entify.dart";

import "init.dart";
import "model.dart";
import "print.dart";

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
    Iterable<Entity> entities = batch.entities;
    printSpeciesEntities(entities, projected: projected);
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
}
