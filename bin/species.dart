import "dart:async";
import "dart:io";

import "package:endangered_species/endangered_species.dart";

// See ../lib/src/init.dart for datastore connection settings

Future<Null> main(List<String> args) async {
  if (args.length == 0) {
    print("Valid commands are:");
    print("  - populate");
    print("  - list");
    print("  - lookup");
    print("  - query");
    return null;
  }

  switch (args[0]) {
    case "populate":
      // simple mutations example
      await populate(args.sublist(1));
      break;
    case "list":
      // simple query without a filter
      await list(args.sublist(1));
      break;
    case "lookup":
      // lookup by key and a query with a simple filter
      await lookup(args.sublist(1));
      break;
    case "query":
      // advanced query
      await query(args.sublist(1));
      break;
    default:
      print("Que?");
      break;
  }
  // somehow it won't exit right away
  exit(0);
}
