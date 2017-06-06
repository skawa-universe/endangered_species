import "dart:async";
import "package:entify/entify.dart";

import "init.dart";
import "model.dart";
import "print.dart";

Future<Null> list(List<String> args) async {
  const int batchSize = 10;

  DatastoreShell dsh = await getDatastoreShell();

  Query q = Species.bridge.query()..limit = batchSize;

  if (args.isNotEmpty && !args.last.startsWith("-")) q.startCursor = args.last;

  QueryResultBatch batch = await dsh.prepareQuery(q).runQuery();
  printSpeciesEntities(batch.entities);
  print("End cursor: ${batch.endCursor}");
}
