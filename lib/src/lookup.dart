import "dart:async";
import "dart:io";
import "package:entify/entify.dart";

import "init.dart";
import "model.dart";
import "print.dart";

Future<Null> lookup(List<String> args) async {
  if (args.length < 2 || args[0] != "sci" && args[0] != "com") {
    stderr.writeln("Usage:");
    stderr.writeln("  - lookup sci <scientific name>");
    stderr.writeln("  - lookup com <common name>");
    return null;
  }

  if (args[0] == "sci") return lookupByKey(new Key(Species.bridge.kind, name: args[1]));
  if (args[0] == "com") return lookupByValue(args[1], args.sublist(2));
}

Future<Null> lookupByKey(Key key) async {
  DatastoreShell dsh = await getDatastoreShell();
  try {
    Species s = new Species.fromEntity(await dsh.getSingle(key));
    printSpecies([s]);
  } on EntityNotFoundError {
    print("No species found with this scientific name: $key");
  }
}

Future<Null> lookupByValue(String commonName, List<String> args) async {
  const int batchSize = 10;

  DatastoreShell dsh = await getDatastoreShell();

  Query q = Species.bridge.query()
    ..limit = batchSize
    ..filter = FilterOperator.equal("commonName", commonName);

  if (args.isNotEmpty && !args.last.startsWith("-")) q.startCursor = args.last;

  QueryResultBatch batch = await dsh.prepareQuery(q).runQuery();
  printSpeciesEntities(batch.entities);
  print("End cursor: ${batch.endCursor}");
}
